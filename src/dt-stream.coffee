{ Stream } = require 'stream'
OrderedEmitter = require 'ordered-emitter'
{ prettify, attrStr } = require './util'

EVENTS = [
    'add', 'close', 'end'
    'attr','text', 'raw', 'data'
]

# TODO drainage
# TODO dont emit data from hidden tags


class Entry
    constructor: (el, @parent) ->
        @order = new OrderedEmitter span:yes
        # states
        @released = no
        @isnext = no
        @children = 0 # we start with 1 to use 0 as pause bit
        # just run the job when it got ready
        @order.on('entry', ({job}) -> job?())
        # tell the parent to write this entry when its time
        @parent?._stream.write =>
            @release() if @children
            @isnext = yes
        # get the order position of this entry
        @idx = @parent?._stream.children ? -1
        # placeholder for close
        @parent?._stream.children++
        # when this entry is ready resume parent
        el.ready =>
            @parent?._stream.emit('close', order:@idx+1)

    emit: ->
        @order.emit(arguments...)

    write: (job) ->
        # no self closing tags please
        @release() if @children and @isnext
        @emit 'entry', {job, order:(++@children)}

    release: () =>
        @emit 'release', {order:0} unless @released
        @released = yes


class StreamAdapter
    constructor: (@template, opts = {}) ->
        @builder = @template.xml ? @template
        @stream = opts.stream ? new Stream
        @stream.readable ?= on
        @opened_tags = 0
        @initialize()

    initialize: () ->
        @template.stream = @stream
        @builder._stream = new Entry @builder
        @builder._stream.release()
        do @listen
        # register ready handler
        @template.register 'ready', (tag, next) ->
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
        @stream.emit('data', data) if data

    close: () =>
        @builder.closed = yes
        @stream.emit 'end'

    # eventlisteners

    onadd: (parent, el) ->
        el._stream = new Entry el, parent
        @opened_tags++
        el._stream.write =>
            if el.closed is 'self'
                @write prettify el, "<#{el.name}#{attrStr el.attrs}/>"
            else
                @write prettify el, "<#{el.name}#{attrStr el.attrs}>"
        el.ready =>
            # close stream if builder is already closed
            @opened_tags--
            if @opened_tags is 0
                @closed?()
                @closed = yes

    onclose: (el) ->
        el._stream.write =>
            unless el.closed is 'self'
                @write prettify el, "</#{el.name}>"
            # call next callback of the registered 'ready' checker
            el._stream_ready?()
            el._stream_ready = yes


    ondata: (el, data) ->
        el._stream.write =>
            @write data

    ontext: (el, text) ->
        el._stream.write =>
            @write prettify el, text

    onraw: (el, html) ->
        el._stream.write =>
            @write html

    onattr: (el, key, value) ->
        return unless el.isempty
        console.warn "attributes of #{el.toString()} don't change anymore"

    onend: () ->
        if @closed? and @opened_tags is 0
            @close()
        else
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
