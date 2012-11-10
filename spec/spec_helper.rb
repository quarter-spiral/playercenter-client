ENV['RACK_ENV'] ||= 'test'

Bundler.require

require 'minitest/autorun'

require 'graph-backend'
require 'auth-backend'
require 'playercenter-backend'
require 'rack/client'

require 'playercenter-client'

def wipe_graph!
  connection = Graph::Backend::Connection.create.neo4j
  (connection.find_node_auto_index('uuid:*') || []).each do |node|
    connection.delete_node!(node)
  end
end
wipe_graph!
