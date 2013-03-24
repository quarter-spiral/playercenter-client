require_relative './spec_helper'

API_APP = Playercenter::Backend::API.new
GRAPH_APP = Graph::Backend::API.new
AUTH_APP = Auth::Backend::App.new(test: true)
DEVCENTER_APP = Devcenter::Backend::API.new
DATASTORE_APP = Datastore::Backend::API.new

module Auth
  class Client
    alias raw_initialize initialize
    def initialize(url, options = {})
      raw_initialize(url, options.merge(adapter: [:rack, AUTH_APP]))
    end
  end
end

module Graph
  class Client
    alias raw_initialize initialize
    def initialize(*args)
      raw_initialize(*args)
      client.raw.adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, GRAPH_APP])
    end
  end
end

module Devcenter
  class Client
    alias raw_initialize initialize
    def initialize(*args)
      raw_initialize(*args)
      client.raw.adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, DEVCENTER_APP])
    end
  end
end

module Datastore
  class Client
    alias raw_initialize initialize
    def initialize(*args)
      raw_initialize(*args)
      client.raw.adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, DATASTORE_APP])
    end
  end
end

module Auth::Backend
  class Connection
    alias raw_initialize initialize
    def initialize(*args)
      result = raw_initialize(*args)

      graph_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, GRAPH_APP])
      @graph.client.raw.adapter = graph_adapter

      result
    end
  end
end

module Devcenter::Backend
  class Connection
    alias raw_initialize initialize
    def initialize(*args)
      result = raw_initialize(*args)

      datatstore_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, DATASTORE_APP])
      @datastore.client.raw.adapter = datatstore_adapter

      graph_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, GRAPH_APP])
      @graph.client.raw.adapter = graph_adapter

      result
    end
  end
end

require 'auth-backend/test_helpers'
auth_helpers = Auth::Backend::TestHelpers.new(AUTH_APP)
oauth_app = auth_helpers.create_app!
ENV['QS_OAUTH_CLIENT_ID'] = oauth_app[:id]
ENV['QS_OAUTH_CLIENT_SECRET'] = oauth_app[:secret]

token = auth_helpers.get_token
user = auth_helpers.user_data

auth_client = Auth::Client.new("http://example.com")
app_token = auth_client.create_app_token(oauth_app[:id], oauth_app[:secret])

describe Playercenter::Client do
  before do
    @client = Playercenter::Client.new('http://example.com')

    adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, API_APP])
    @client.client.raw.adapter = adapter
  end

  it "can retrieve information about players" do
    venue_options = {"venue-id" => "2354243", "name" => "Peter Smith"}
    venue_token = auth_client.venue_token(app_token, 'facebook', venue_options)
    venue_uuid = auth_client.token_owner(venue_token)['uuid']
    auth_client.attach_venue_identity_to(venue_token, venue_uuid, 'spiral-galaxy', {"venue-id" => "674735", "name" => "Pete"})

    info = @client.info_about(venue_uuid, venue_token)
    info['uuid'].must_equal venue_uuid
    info['venues'].keys.size.must_equal 2
    info['venues']['facebook'].must_equal("id" => venue_options['venue-id'], "name" => venue_options['name'])
    info['venues']['spiral-galaxy'].must_equal("id" => '674735', "name" => 'Pete')
  end

  it "returns nil when retrieving information about a non existing player" do
    @client.info_about("9999999999", token).must_equal nil
  end

  it "does not work with a bogus token" do
    lambda {
      @client.info_about(user['uuid'], 'bogus-token')
    }.must_raise Service::Client::ServiceError
  end

  it "can register a player at a game" do
    venue_options = {"venue-id" => "2354243", "name" => "Peter Smith"}
    venue_token = auth_client.venue_token(app_token, 'facebook', venue_options)
    player_uuid = auth_client.token_owner(venue_token)['uuid']

    graph_client = Graph::Client.new('http://graph-backend.dev')
    graph_client.add_role(player_uuid, app_token, 'developer')
    game_options = {:name => "Test Game 1", :description => "Good game 1", :configuration => {'type' => 'html5', 'url' => 'http://example.com/1'},:developers => [player_uuid], :venues => {"facebook" => {"enabled" => true, "app-id" => "123", "app-secret" => "456"}}, :category => 'Jump n Run'}
    game_uuid = Devcenter::Backend::Game.create(app_token, game_options).uuid

    game_options = {:name => "Test Game 2", :description => "Good game 2", :configuration => {'type' => 'html5', 'url' => 'http://example.com/2'},:developers => [player_uuid], :venues => {"facebook" => {"enabled" => true, "app-id" => "123", "app-secret" => "456"}}, :category => 'Jump n Run'}
    game2_uuid = Devcenter::Backend::Game.create(app_token, game_options).uuid

    @client.list_games(player_uuid, token).empty?.must_equal true

    @client.register_player(player_uuid, game_uuid, 'facebook', token)
    games = @client.list_games(player_uuid, token)
    games.size.must_equal 1
    games.select {|g| g['uuid'] == game_uuid}.empty?.must_equal false

    @client.register_player(player_uuid, game_uuid, 'facebook', token)
    games = @client.list_games(player_uuid, token)
    games.size.must_equal 1
    games.select {|g| g['uuid'] == game_uuid}.empty?.must_equal false

    @client.register_player(player_uuid, game2_uuid, 'galaxy-spiral', token)
    games = @client.list_games(player_uuid, token)
    games.size.must_equal 2
    games.select {|g| g['uuid'] == game_uuid}.empty?.must_equal false
    games.select {|g| g['uuid'] == game2_uuid}.empty?.must_equal false
  end

  it "can updates friends of a user" do
    venue_options = {"venue-id" => "2354243", "name" => "Peter Smith"}
    venue_token = auth_client.venue_token(app_token, 'facebook', venue_options)
    uuid = auth_client.token_owner(venue_token)['uuid']

    friend_1 = {"venue-id" => "576765463", "name" => "Sam Jackson"}
    friend_2 = {"venue-id" => "785254235", "name" => "Jack Bowers"}

    @client.update_friends_of(uuid, venue_token, 'facebook', [friend_1, friend_2])

    friends = @client.friends_of(uuid, venue_token)
    friends.keys.size.must_equal 3

    friends.values.select {|v| v['facebook'] == {"id" => venue_options['venue-id'], "name" => venue_options['name']}}.empty?.must_equal false
    friends.values.must_include("facebook" => {"id" => friend_1['venue-id'], "name" => friend_1['name']})
    friends.values.must_include("facebook" => {"id" => friend_2['venue-id'], "name" => friend_2['name']})
  end
end
