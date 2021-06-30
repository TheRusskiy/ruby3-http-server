require_relative 'ractor_server'
require_relative 'file_serving_app'

RactorServer.new(FileServingApp.new).start
