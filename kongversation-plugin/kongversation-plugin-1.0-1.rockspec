package = "kongversation-plugin"
version = "1.0-1"
source = {
 url = ".",
}
description = {
 summary = "kongversation-plugin plugin",
 license = "MIT",
}
dependencies = {
 "kong >= 3.6.0",
 "lua >= 5.1"
}
build = {
 type = "builtin",
 modules = {
   ["kong.plugins.kongversation-plugin.handler"] = "kong/plugins/kongversation-plugin/handler.lua",
   ["kong.plugins.kongversation-plugin.schema"] = "kong/plugins/kongversation-plugin/schema.lua",
 },
}