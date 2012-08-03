# [Δt Stream Adapter](https://github.com/dodo/node-dt-selector/)

This is a stream adapter for [Δt](http://dodo.github.com/node-dynamictemplate/).


## Installation

```bash
$ npm install dt-stream
```


## Usage

```javascript
var Template = require('dynamictemplate').Template;
var streamify = require('dt-stream');

var template = streamify(new Template({schema:5, pretty:true}, function () {
    this.$html(function () {
        this.$body("hello world");
    });
}));

template.stream.pipe(process.stdout);

/* → stdout:
<html>
  <body>
    hello world
  </body>
</html>
*/
```

## api

Returns a normal [nodejs stream](http://nodejs.org/api/stream.html) and emits the template as string data.

Δt is already packed with a [simple render function](https://github.com/dodo/node-dynamictemplate/blob/master/src/render.coffee) to use this adapter to stream templates out through for example a http request.

__Note__

Unfortunatily this disables the ability to change the template after it was rendered, but asyncronious operations like filesystem io still works pretty well.



