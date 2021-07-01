require_relative 'ractor_server'
require_relative 'fiber_server'
require_relative 'single_threaded_server'
require_relative 'multi_threaded_server'
require_relative 'file_serving_app'

# SERVER = FiberServer
# SERVER = SingleThreadedServer
SERVER = MultiThreadedServer
# SERVER = RactorServer

SERVER.new(FileServingApp.new).start
