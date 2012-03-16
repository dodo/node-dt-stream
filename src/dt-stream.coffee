{ Stream } = require 'stream'
OrderedEmitter = require 'ordered-emitter'
{ delay, release, prettify, attrStr } = require './util'

EVENTS = [
    'add', 'close', 'end'
    'attr','text', 'raw', 'data'
]

# TODO drainage
# TODO dont emit data from hidden tags


class Entry
    constructor: (el, @parent) ->
        @order = new OrderedEmitter span:yes
        @released = no
        @isnext = no
        @children = 0 # we start with 1 to use 0 as pause bit
        @order.on('entry', ({job}) -> job?())
        @parent?._stream.write =>
            @release() if @children
            @isnext = yes
        @idx = @parent?._stream.children ? -1
        @parent?._stream.children++ # placeholder for close
        el.once 'ready', =>
            @parent?._stream.order.emit('close', order:@idx+1)

    write: (job) ->
        @release() if @children and @isnext
        @order.emit 'entry', {job, order:(++@children)}

    release: () =>
        @order.emit 'release', {order:0} unless @released
        @released = yes


class StreamAdapter
    constructor: (@template, opts = {}) ->
        @builder = @template.xml ? @template
        @stream = opts.stream ? new Stream
        @stream.readable ?= on
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

    # eventlisteners

    onadd: (parent, el) ->
        el._stream = new Entry el, parent
        el._stream.write =>
            if el.closed is 'self'
                @write prettify el, "<#{el.name}#{attrStr el.attrs}/>"
            else
                @write prettify el, "<#{el.name}#{attrStr el.attrs}>"

    onclose: (el) ->
        el._stream.write =>
            unless el.closed is 'self'
                @write prettify el, "</#{el.name}>"
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

    onend: (r = 0) ->
        @stream.emit 'end'



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
