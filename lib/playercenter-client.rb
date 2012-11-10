require "playercenter-client/version"

require "service-client"

module Playercenter
  class Client
    API_VERSION = 'v1'

    attr_reader :client

    def initialize(url)
      @client = Service::Client.new(url)

      # Info
      @client.urls.add(:info, :get,    "/#{API_VERSION}/:uuid:")

      # Friends
      @client.urls.add(:friends, :get,  "/#{API_VERSION}/:uuid:/friends")
      @client.urls.add(:friends, :put,  "/#{API_VERSION}/:uuid:/friends/:venue:")
    end

    def info_about(uuid, token)
      @client.get(@client.urls.info(uuid: uuid), token).data
    rescue Service::Client::ServiceError => e
      return nil if e.error =~ /venue ids not found/
      raise e
    end

    def friends_of(uuid, token)
      @client.get(@client.urls.friends(uuid: uuid), token).data
    end

    def update_friends_of(uuid, token, venue, friends_venue_data)
      @client.put(@client.urls.friends(uuid: uuid, venue: venue), token, "friends" => friends_venue_data).data
    end
  end
end

