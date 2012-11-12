# Playercenter::Client

Client to the playercenter-backend.

## Usage

### Create a client

```ruby
# connect to local
client =
Playercenter::Client.new('http://playercenter-backend.dev')
```

### Retrieve information about a user

```ruby
info = client.info_about(uuid, token)
info # => {
     #      "uuid" => "453455535",
     #      "venue" => {
     #        "facebook" => {
     #          "id" => "87432",
     #          "name" => "Peter Smith"
     #        },
     #        "spiral-galaxy" => {
     #          "id" => "124890",
     #          "name" => "Pete S"
     #        }
     #      }
     #    }
```

### Friends

#### List friends of a user

```ruby
friends = client.friends_of(uuid, token)
friends # => {
        #      "453455535" => {
        #        # A hash like the one you get when
        #        # Retrieving information about a user
        #      },…
        #    }
```

#### Updates friends of a user

```ruby
friends_venue_data = [
  {"venue-id" => "87432", "name" => "Peter Smith"},
  {"venue-id" => "90843", "name" => "Sam Jackson"}
]

venue = "facebook"
client.update_friends_of(uuid, token, venue, friends_venue_data)
```
