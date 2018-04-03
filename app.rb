
require 'sinatra'
require 'net/http'
require 'json'
require 'SQLite3'

CLIENT_ID = ENV.fetch('PROCORE_CLIENT_ID')
CLIENT_SECRET= ENV.fetch('PROCORE_CLIENT_SECRET')
REDIRECT_URL = ENV.fetch('PROCORE_OAUTH2_REDIRECT_URI')

enable :sessions

get '/' do
  # This will render the HTML markup below
  erb :index
end

get '/signin' do
  erb :signin
end

get '/callback' do
  # Pull the authorization code from the code parameter
  authorization_code = params["code"]

  # Exchange endpoint
  uri = URI.parse("https://app.procore.com/oauth/token")

  # Post to /oauth/token with required information
  response = Net::HTTP::post_form(uri, {
    "grant_type" => "authorization_code",
    "client_id" => CLIENT_ID,
    "client_secret" => CLIENT_SECRET,
    "code" => authorization_code,
    "redirect_uri" => REDIRECT_URL
  })

  # Parse JSON response
  json = JSON.parse(response.body)

  # Me Endpoint
  me_uri = URI.parse("https://app.procore.com/vapid/me")
  me_request = Net::HTTP::Get.new(me_uri)

  # Set authorization header
  me_request["authorization"] = "Bearer #{json['access_token']}"

  me_response = Net::HTTP.start(me_uri.hostname, me_uri.port, use_ssl: true) do |http|
    http.request(me_request)
  end

  # Parse response
  me_json = JSON.parse(me_response.body)

  # Establish connection to database
  db = SQLite3::Database.new("test.db")

  # Look up user by ProcoreID
  user = db
    .execute("select * from users where procore_id = ?", me_json["id"])
    .first

  # User does not exist - create them in the database
  if user.nil?
    db.execute(
      "INSERT INTO users (procore_id, email) VALUES (?, ?)",
      [me_json["id"], me_json["login"]]
    )
    session["user_id"] = db.last_insert_row_id
  else
    # User already exists, sign them in
    session["user_id"] = user[0]
  end

  redirect to('/home')
end

get '/home' do
  # Open a connection to the database
  db = SQLite3::Database.new("test.db")

  # Pull the current user out of the database - user who’s id matches the id
  # stored in the session
  user = db
    .execute("select * from users where id = ?", session["user_id"])
    .first

  # Print the user as a string for the browser
  user.to_s
end

__END__

@@index
  <style>
    .signup-form {
      margin: 48px 0;
      text-align: center;
    }

    a {
      background-color: #f47e42;
      color: #fff;
      font-family: sans-serif;
      padding: 12px;
      text-decoration: none;
    }
  </style>
  <div class="signup-form">
    <a href='<%= "https://app.procore.com/oauth/authorize?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{REDIRECT_URL}" %>'>
      Sign Up with Procore
    </a>
  </div>

@@signin
  <style>
    .signin-form {
      margin: 48px 0;
      text-align: center;
    }

    a {
      background-color: #f47e42;
      color: #fff;
      font-family: sans-serif;
      padding: 12px;
      text-decoration: none;
    }
  </style>
  <div class="signin-form">
    <a href='<%= "https://app.procore.com/oauth/authorize?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{REDIRECT_URL}" %>'>
        Sign In with Procore
    </a>
  </div>
© 2018 Procore. All rights reserved
