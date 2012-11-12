require_relative './spec_helper'

API_APP = Playercenter::Backend::API.new
GRAPH_APP = Graph::Backend::API.new
AUTH_APP = Auth::Backend::App.new(test: true)

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

  it "can updates friends of a user" do
    venue_options = {"venue-id" => "2354243", "name" => "Peter Smith"}
    venue_token = auth_client.venue_token(app_token, 'facebook', venue_options)
    uuid = auth_client.token_owner(venue_token)['uuid']

    friend_1 = {"venue-id" => "576765463", "name" => "Sam Jackson"}
    friend_2 = {"venue-id" => "785254235", "name" => "Jack Bowers"}

    @client.update_friends_of(uuid, venue_token, 'facebook', [friend_1, friend_2])

    friends = @client.friends_of(uuid, venue_token)
    friends.keys.size.must_equal 2

    friends.values.must_include("facebook" => {"id" => friend_1['venue-id'], "name" => friend_1['name']})
    friends.values.must_include("facebook" => {"id" => friend_2['venue-id'], "name" => friend_2['name']})
  end
end
