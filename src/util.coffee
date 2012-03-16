
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


# exports

module.exports = {
    indent,
    breakline,
    prettify,
    attrStr,
}
