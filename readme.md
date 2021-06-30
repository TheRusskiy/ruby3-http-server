# Ruby 3 HTTP Server

This project demonstrates a toy implementation of an HTTP server using Ractors / Fibers from Ruby 3

**Important**: Ractors as Ruby team states are not production ready, you may experience random segfaults and random errors, nevertheless this approach may be viable in the future and presents a great learning opportunity

## Usage

1. Make sure you have ruby 3.0.x installed.
2. Edit start.rb to select the server you want to run
3. Run:
```
bundle install
bundle exec ruby start.rb
```

You can send requests via 
```
ab -n 10000 -c 4 http://127.0.0.1:3000/test.txt
```
