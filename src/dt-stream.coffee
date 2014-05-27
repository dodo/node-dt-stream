{ Stream } = require 'stream'
OrderedEmitter = require 'ordered-emitter'
{ prettify, attrStr } = require './util'

EVENTS = [
    'add', 'close', 'end', 'remove',
    'attr','text', 'raw', 'data'
]

# TODO dont emit data from hidden tags


class Entry
    constructor: (@stream, el, @parent) ->
        @order = new OrderedEmitter span:yes
        # states
        @released = no
        @isnext = if @parent? then no else yes
        @children = 0 # we start with 1 to use 0 as pause bit
        # just run the job when it got ready
        @order.on('entry', @do_job)
        return if @isnext
        # tell the parent to write this entry when its time
        @parent?._stream.write =>
            @release() if not el.isempty or el.closed is yes
            @isnext = yes
        # get the order position of this entry
        idx = @parent?._stream.children ? -1
        # placeholder for close
        @parent?._stream.children++
        # when this entry is ready resume parent
        el.ready ->
            @parent?._stream.emit('close scope', order:idx+1)
        @parent?._stream.release()

    do_job: ({job}) =>
        return unless job
        if @stream.paused
            @stream.queue.push(job)
        else
            do job

    emit: ->
        @order?.emit(arguments...)

    write: (job) ->
        payload = {job, order:(++@children)}
        if @stream.paused
            # no self closing tags please
            @stream.queue.push(@release) if @children > 1 and @isnext
            # delay until stream resumes
            @stream.queue.push(@emit.bind(this, 'entry', payload))
        else
            # no self closing tags please
            @release() if @children > 1 and @isnext
            @emit 'entry', payload

    release: () =>
        return if @released
        @emit 'open scope', {order:0}
        @released = yes

    delete: () =>
        @order.removeAllListeners()
        @order.reset()
        @order.clear()
        delete @parent
        delete @order


class StreamAdapter extends Stream # Readable
    constructor: (@template, opts = {}) ->
        super()
        @builder = @template.xml ? @template
        @autoremove = opts.autoremove ? on
        @encoding = opts.encoding ? 'utf8'
        @opened_tags = 0
        @readable = yes
        @paused = no
        @queue = []
        # initialize
        @pipe(opts.stream) if opts.stream
        @initialize()

    initialize: () ->
        @template.stream = this
        @builder._stream = new Entry this, @builder
        do @listen
        # register ready handler
        @template.register('ready', @approve_ready)

    approve_ready: (tag, next) ->
        # when tag is already in the dom its fine,
        #  else wait until it is inserted into dom
        if tag._stream_ready is yes
            next(tag)
        else
            tag._stream_ready = ->
                next(tag)

    listen: () ->
        EVENTS.forEach (event) =>
            @template.on(event, this["on#{event}"].bind(this))

    write: (data) ->
        return unless data
        @emit('error', "write data while paused") if @paused
        @emit('data', data)

    close: () =>
        @builder.closed = yes
        @readable = no
        @emit 'end'
        @emit 'close'

    # Readable API

    setEncoding: (@encoding) ->

    pause: () ->
        return if @paused
        @paused = yes
        @emit 'pause'
        @template.emit 'pause'

    resume: () ->
        if @paused
            @emit 'resume'
            @template.emit 'pause'
            @paused = no
        @queue.shift()?() while not @paused and @queue.length
        if @closed? and not @queue.length
            @closed?()
            @closed = yes
        return

    # eventlisteners

    onadd: (parent, el) ->
        unless parent.writable
            console.warn "creating #{el.toString()} in closed #{parent.toString()} omitted"
            return
        el._stream = new Entry this, el, parent
        @opened_tags++
        el._stream.write =>
            return if el is el.builder
            if el.isempty and el.closed is yes
                @write prettify el, "<#{el.name}#{attrStr el.attrs}/>"
            else
                @write prettify el, "<#{el.name}#{attrStr el.attrs}>"
        return unless @autoremove
        el.ready =>
            if el.closed is 'removed'
                @onremove(el)
            else
                el.remove() # prevent memory leak

    onremove: (el) ->
        return unless el._stream?
        # close stream if builder is already closed
        @opened_tags--
        if @opened_tags is 0 and @builder.closed is 'pending' and not @queue.length
            @closed?()
            @closed = yes
        el._stream.write ->
            # cleanup element
            el._stream.delete()
            delete el._stream

    onclose: (el) ->
        el._stream?.write =>
            unless el.isempty or el is el.builder
                @write prettify el, "</#{el.name}>"
            # call next callback of the registered 'ready' checker
            el._stream_ready?()
            el._stream_ready = yes

    ondata: (el, data) ->
        el._stream?.write =>
            @write data

    ontext: (el, text) ->
        el._stream?.write =>
            @write prettify el, text

    onraw: (el, html) ->
        el._stream?.write =>
            @write html

    onattr: (el, key, value) ->
        return unless el.isempty
        return unless el._stream_ready is yes
        console.warn "attributes of #{el.toString()} don't change anymore"

    onend: () ->
        return @close() if @closed? or @opened_tags is 0
        # delay until last tag gets closed and written out
        @builder.closed = 'pending'
        @closed = @close




streamify = (tpl, opts) ->
    new StreamAdapter(tpl, opts)
    return tpl

# exports

streamify.Adapter = StreamAdapter
module.exports = streamify

# browser support

( ->
    if @dynamictemplate?
        @dynamictemplate.streamify = streamify
    else
        @dynamictemplate = {streamify}
).call window if process.title is 'browser'
