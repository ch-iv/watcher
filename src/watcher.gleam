import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string_builder
import mist
import wisp

const port = 8000

pub fn new() -> Result(process.Subject(Message), actor.StartError) {
  actor.start(0, handle_message)
}

pub fn increment(counter: process.Subject(Message)) -> Result(Int, Nil) {
  actor.call(counter, Increment, 100)
}

pub type Message {
  Increment(reply_with: process.Subject(Result(Int, Nil)))
}

pub fn handle_message(message: Message, count: Int) -> actor.Next(Message, Int) {
  case message {
    Increment(counter) -> {
      actor.send(counter, Ok(count))
      actor.continue(count + 1)
    }
  }
}

/// The HTTP request handler- your application!
/// 
pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  // Permit browsers to simulate methods other than GET and POST using the
  // `_method` query parameter.
  let req = wisp.method_override(req)

  // Log information about the request and response.
  use <- wisp.log_request(req)

  // Return a default 500 response if the request handler crashes.
  use <- wisp.rescue_crashes

  // Rewrite HEAD requests to GET requests and return an empty body.
  use req <- wisp.handle_head(req)

  // Handle the request!
  handle_request(req)
}

pub fn handle_request(
  req: wisp.Request,
  counter: process.Subject(Message),
) -> wisp.Response {
  // Apply the middleware stack for this request/response.
  use req <- middleware(req)

  case wisp.path_segments(req) {
    [] -> {
      let assert Ok(count) = increment(counter)
      let body =
        string_builder.from_string(
          "<h1>Your number is " <> int.to_string(count) <> "</h1>",
        )
      wisp.html_response(body, 200)
    }

    ["random"] -> {
      let body =
        string_builder.from_string(
          "<h1>The random number is "
          <> int.to_string(int.random(9_999_999))
          <> "</h1>",
        )
      wisp.html_response(body, 200)
    }
    _ -> wisp.not_found()
  }
}

pub fn scanner() {
  io.println("Started the scanner")

  let urls = [
    "http://localhost:" <> int.to_string(port) <> "/",
    "http://localhost:" <> int.to_string(port) <> "/random",
  ]

  list.each(urls, fn(url) {
    let assert Ok(req) = request.to(url)
    case httpc.send(req) {
      Ok(resp) -> io.println(url <> ":\n" <> resp.body)
      _ -> io.println("Error fetching " <> url)
    }
  })

  process.sleep(500)
  scanner()
}

pub fn main() {
  io.println("Hello from watcher!")

  // The counter actor is a proccess that stores internal state and updates it 
  // based on the recieved messages
  let assert Ok(counter) = new()

  // wisp.configure_logger()

  // Here we generate a secret key, but in a real application you would want to
  // load this from somewhere so that it is not regenerated on every restart.
  let secret_key_base = wisp.random_string(64)

  // Start the Mist web server.
  let assert Ok(_) =
    wisp.mist_handler(handle_request(_, counter), secret_key_base)
    |> mist.new
    |> mist.port(port)
    |> mist.start_http

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.start(scanner, True)
  process.sleep_forever()
}
