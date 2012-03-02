{ Stream } = require 'stream'
{ delay, release, prettify, attrStr } = require './util'

EVENTS = [
    'add', 'close', 'end'
    'attr','text', 'raw', 'data'
]

# TODO drainage
# TODO dont emit data from hidden tags


class StreamAdapter
    constructor: (@template, opts = {}) ->
        @builder = @template.xml ? @template
        @stream = opts.stream ? new Stream
        @stream.readable ?= on
        @initialize()

    initialize: () ->
        @template.stream = @stream
        @builder._streamed = yes
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
        # insert into parent
        delay.call el, =>
            if el.closed is 'self'
                @write prettify el, "<#{el.name}#{attrStr el.attrs}/>"
            else
                @write prettify el, "<#{el.name}#{attrStr el.attrs}>"

        delay.call parent, ->
            return unless el.closed
            el._streamed = yes
            release.call el

        release.call parent if el is parent.pending[0]

    onclose: (el) ->
        delay.call el, =>
            unless el.closed is 'self'
                @write prettify el, "</#{el.name}>"
            el._stream_ready?()
            el._stream_ready = yes

            release.call el.parent if el is el.parent.pending[0]
        if el.closed and el is el.parent.pending[0]
            release.call el

    ondata: (el, data) ->
        delay.call el, =>
            @write data

    ontext: (el, text) ->
        delay.call el, =>
            @write prettify el, text

    onraw: (el, html) ->
        delay.call el, =>
            @write html

    onattr: (el, key, value) ->
        return unless el.isempty
        console.warn "attributes of #{el.toString()} don't change anymore"

    onend: () ->
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
