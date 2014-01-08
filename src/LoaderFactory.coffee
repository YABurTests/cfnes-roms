###########################################################
# Factory for loaders
###########################################################

class LoaderFactory

    constructor: ->
        @loaderClasses = []
        @registerLoader "INESLoader"

    registerLoader: (name) ->
        @loaderClasses.push require "./loaders/#{name}"

    createLoader: (reader) ->
        for loaderClass in @loaderClasses
            reader.reset()
            if loaderClass.supportsInput reader
                return new loaderClass reader
        throw "Unsupported cartridge ROM format."

module.exports = LoaderFactory