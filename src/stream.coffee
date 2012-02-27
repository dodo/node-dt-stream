{ Stream } = require 'stream'

# TODO drainage

indent = ({level, pretty}) ->
    pretty = "  " if pretty is on
    return new Array(level + 1).join(pretty)


breakline = ({level, pretty}, data) ->
    return data unless pretty
    if data?[data?.length-1] is "\n"
        return data
    else
        return "#{data}\n"


prettify = (el, data) ->
    unless el?.pretty
        return data
    else
        return "#{indent el}#{breakline el, data}"


attrStr = (attrs = {}) ->
    strattrs = for k, v of attrs
        if v?
            v = "\"#{v}\"" unless typeof v is 'number'
            "#{k}=#{v}"
        else "#{k}"
    strattrs.unshift '' if strattrs.length
    strattrs.join ' '



removed = (el) ->
    el.closed is "removed"

# delay or invoke job immediately
delay = (job) ->
    return if removed this
    # only when tag is ready
    if @_streamed?
        do job
    else
        @_stream_buffer?= []
        @_stream_buffer.push(job)


# invoke all delayed stream work
release = () ->
    if @_stream_buffer?
        for job in @_stream_buffer
            do job
        delete @_stream_buffer


#return true if @hidden # dont emit data when this tag is hidden # FIXME
streamify = (tpl) ->
    stream = new Stream
    stream.readable = on

    write = (data) ->
        stream.emit('data', data) if data

    tpl.stream = stream
    builder = tpl.xml ? tpl
    builder._streamed = yes

    tpl.on 'add', (parent, el) ->
        # insert into parent
        delay.call el, ->
            if el.closed is 'self'
                write prettify el, "<#{el.name}#{attrStr el.attrs}/>"
            else
                write prettify el, "<#{el.name}#{attrStr el.attrs}>"

        delay.call parent, ->
            return unless el.closed
            el._streamed = yes
            release.call el

        release.call parent if el is parent.pending[0]

    tpl.on 'close', (el) ->
        delay.call el, ->
            unless el.closed is 'self'
                write prettify el, "</#{el.name}>"
            release.call el.parent if el is el.parent.pending[0]
        if el.closed and el is el.parent.pending[0]
            release.call el

    tpl.on 'data', (el, data) ->
        delay.call el, ->
            write data

    tpl.on 'text', (el, text) ->
        delay.call el, ->
            write text

    tpl.on 'raw', (el, html) ->
        delay.call el, ->
            write html

    tpl.on 'attr', (el, key, value) ->
        return unless el.isempty
        console.warn "attributes of #{el.toString()} don't change anymore"

    tpl.on 'end', ->
        stream.emit 'end'

# exports

module.exports = streamify

# browser support

( ->
    if @dynamictemplate?
        @dynamictemplate.streamify = streamify
    else
        @dynamictemplate = {streamify}
).call window if process.title is 'browser'
