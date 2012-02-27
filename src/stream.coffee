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
    if @_streamed? and @closed
        do job
    else
        @_stream_buffer?= []
        @_stream_buffer.push(job)


# invoke all delayed stream work
release = () ->
#     console.log "release", @name, attrStr(@attrs), @_stream_buffer
    if @_stream_buffer?
        for job in @_stream_buffer
            do job
        delete @_stream_buffer


#return true if @hidden # dont emit data when this tag is hidden # FIXME
streamify = (tpl) ->
#     buffer = null
    stream = new Stream
    stream.readable = on

    write = (data) ->
        stream.emit('data', data) if data

    tpl.stream = stream
    builder = tpl.xml ? tpl
    builder._streamed = yes

#     tpl.on 'add', (parent, el) ->
#         console.log "add", el.name, attrStr(el.attrs)
#         write buffer
#         buffer = prettify el, "<#{el.name}#{attrStr el.attrs}>"

    tpl.on 'add', (parent, el) ->
        # insert into parent
#         unless parent.closed is 'pending'
#         release.call parent if parent._streamed?
        if parent is builder
            target = el
        else
            target = parent
        delay.call target, ->
            console.log "write", el.name, el.closed, el._streamed
            if el.closed is 'self'
                write prettify el, "<#{el.name}#{attrStr el.attrs}/>"
            else
                write prettify el, "<#{el.name}#{attrStr el.attrs}>"
                release.call el unless parent is builder
            el._streamed = yes

        console.log "add", el.name, attrStr(el.attrs), "(#{parent.name})", el._stream_buffer?.length, (el is parent.pending[0]), parent._streamed
#         release.call parent if el is parent.pending[0]

    tpl.on 'close', (el) ->
        console.log "close", el.name, attrStr(el.attrs), el.closed, el.isempty, (el is el.parent.pending[0])
#         buffer = null
#         delay.call el.parent, ->
#         if el is el.parent.pending[0]
#             release.call el.parent
#             target = el.parent
#             t = el
#         else
#             target = el
#             t = el.parent
        delay.call el, ->
#             release.call el
            unless el.closed is 'self'
                write prettify el, "</#{el.name}>"
#             el._streamed = yes
        release.call el if el.parent is builder#el.parent._streamed?
#         release.call el.parent if el is el.parent.pending[0]

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
        console.log "tpl end"
#         release.call builder
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
