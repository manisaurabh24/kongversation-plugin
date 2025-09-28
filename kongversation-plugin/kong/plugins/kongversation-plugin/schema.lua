local typedefs = require "kong.db.schema.typedefs"

local PLUGIN_NAME = "request-payload-chain-plugin"

local schema = {
  name = PLUGIN_NAME,
  fields = {
    { consumer = typedefs.no_consumer }, -- global/service/route scoped only
    { protocols = typedefs.protocols_http }, -- http/https
    { config = {
        type = "record",
        fields = {
          { redis_host = { type = "string", required = false, len_min = 1 } },
          { redis_port = { type = "integer", required = false, between = {1, 65535}, default = 6379 } },
          { redis_username = { type = "string", required = false } }, -- Redis ACL username (Redis 6+)
          { redis_password = { type = "string", required = false, encrypted = true } }, -- secret at rest
          { redis_ssl = { type = "boolean", default = false } },
          { redis_ssl_verify = { type = "boolean", default = false } },
          { redis_server_name = { type = "string", required = false } }, -- SNI for TLS
          { redis_timeout = { type = "integer", default = 2000 } }, -- ms
          { redis_database = { type = "integer", default = 0 } }, -- SELECT index
          { key_namespace = { type = "string", default = "cacheandadd" } }, -- prefix
          { cache_ttl = { type = "integer", default = 3600 } }, -- seconds
          { request_array_field = { type = "string", default = "a" } }, -- JSON array field name
          { apikey_header = { type = "string", default = "apikey" } },
          { max_items = { type = "integer", default = 1000 } }, -- prevent unbounded growth
          { deduplicate = { type = "boolean", default = true } }, -- avoid duplicates
          { forward_mode = { type = "string", one_of = { "full", "append-only" }, default = "full" } },
          { log_level = { type = "string", one_of = { "debug","info","warn","error" }, default = "info" } },
        },
      },
    },
  },
}

return schema
