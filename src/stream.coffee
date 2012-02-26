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


#return true if @hidden # dont emit data when this tag is hidden # FIXME
streamify = (tpl) ->
    stream = new Stream
    stream.readable = on

    emit = (data) ->
        stream.emit('data', data)

    _write = (data) ->
        return if @hidden
        if @_stream.before is null
#             console.log "write", @name, attrStr(@attrs), data
            emit data
        else
#             console.log "buffer", @name, attrStr(@attrs), data
            @_stream.buffer.push data

    write_head = ->
        if @isempty and not @closed
#             console.log "head", @name, attrStr(@attrs)
            _write.call this, prettify this, "<#{@name}#{attrStr @attrs}>"

    write = (data) ->
        write_head.call this
        _write.call this, data

    builder = tpl.xml ? tpl
    tpl.stream = stream
    builder._stream =
        buffer:[]
        before:null
        after:null
        first:null
        last:null

    tpl.on 'add', (parent, el) ->
        console.log "add", el.name, attrStr(el.attrs)
        write_head.call parent
        parstream = parent._stream
        el._stream =
            buffer:[]
            before:parstream.last
            after:null
            first:null
            last:null
        parstream.last?.after = el
        parstream.first ?= el
        parstream.last = el

    tpl.on 'close', (el) ->

        console.log "close", el.name, attrStr(el.attrs), el.closed, el.isempty
        if el._stream.before
            cur = el._stream
            after  = cur.after?._stream
            before = cur.before._stream
            before.buffer = before.buffer?.concat(cur.buffer)
            after?.before = cur.before
            before.after  = cur.after
            if el is el.parent._stream.last
                el.parent._stream.last = cur.before
            el._stream = "done"
            return
        while el?.closed
            break unless el.parent._stream.first is el
            # empty buffer
            emit data for data in el._stream.buffer
            if el.closed is 'self'
                data = "<#{el.name}#{attrStr el.attrs}/>"
            else
                data = "</#{el.name}>"
#             console.log el.name, attrStr(el.attrs), el.isempty, el.closed, data
            write.call el, prettify el, data
            # update linked list
            el._stream.after?.before = null
            if el is el.parent._stream.first
                el.parent._stream.first = el._stream.after
            if el is el.parent._stream.last
                el.parent._stream.last = null
            el._stream = "done"
            el = el._stream.after
        0

    tpl.on 'data', (el, data) ->
        write.call el, data

    tpl.on 'text', (el, text) ->
        write.call el, text

    tpl.on 'raw', (el, html) ->
        write.call el, html

    tpl.on 'data', (el, data) ->
        write.call el, data

    tpl.on 'attr', (el, key, value) ->
        return unless el.isempty
        console.warn "attributes of #{el.toString()} don't change anymore"

    tpl.on 'end', ->
        console.log "tpl end"
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
