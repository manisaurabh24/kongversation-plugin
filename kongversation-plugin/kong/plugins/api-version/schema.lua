local typedefs = require "kong.db.schema.typedefs"

local PLUGIN_NAME = "api-version"

return {
  name = PLUGIN_NAME,
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    {
      config = {
        type = "record",
        fields = {
          {
            request_header = typedefs.header_name {
              required = true,
              default = "X-Api-Version-Req"
            }
          },
          {
            response_header = typedefs.header_name {
              required = true,
              default = "X-Api-Version"
            }
          },
          {
            version_value = {
              type = "string",
              required = true,
              default = "1.0.0"
            }
          }
        },
        entity_checks = {
          { distinct = { "request_header", "response_header" } }
        }
      }
    }
  }
}
