local plugin = {
  PRIORITY = 1000,
  VERSION = "0.1.0",
}

function plugin:access(conf)
  kong.service.request.set_header(conf.request_header, conf.version_value)
end

function plugin:header_filter(conf)
  kong.response.set_header(conf.response_header, conf.version_value)
end

return plugin
``
