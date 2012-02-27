
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
            v = "\"#{v}\"" unless typeof v is 'number' or typeof v is 'boolean'
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


# exports

module.exports = {
    indent,
    breakline,
    prettify,
    attrStr,
    removed,
    delay,
    release,
}
