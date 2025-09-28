local cjson = require "cjson.safe"
local kong = kong

local PLUGIN = {
  PRIORITY = 950,
  VERSION = "1.0.2",
}

-- Deduplicate while preserving order
local function dedup(arr)
  local seen, out = {}, {}
  for _, v in ipairs(arr) do
    if v ~= nil and v ~= cjson.null then
      local key
      if type(v) == "table" then
        key = cjson.encode(v) -- encode tables for dedup key
      else
        key = tostring(v)
      end
      if not seen[key] then
        seen[key] = true
        out[#out+1] = v
      end
    end
  end
  return out
end

-- Keep only last maxn items
local function clamp(arr, maxn)
  if #arr <= maxn then return arr end
  local start = #arr - maxn + 1
  local out, j = {}, 1
  for i = start, #arr do
    out[j] = arr[i]; j = j + 1
  end
  return out
end

local function cache_key(ns, apikey)
  return ns .. ":apikey:" .. apikey
end

-- Loader factory to return an initial value
local function load_or_init_with(initial)
  return function(_key)
    return initial or {}
  end
end

function PLUGIN:access(conf)
  local key = kong.request.get_header(conf.apikey_header or "apikey")
  if not key or key == "" then
    return kong.response.exit(401, { message = "API key missing" })
  end

  -- Flags
  local skip_history = kong.request.get_header("x-skip-history")
  local clear_cache  = kong.request.get_header("x-clear-history")

  local k = cache_key(conf.key_namespace or "cacheandadd", key)

  -- Clear cache if requested
  if clear_cache and clear_cache:lower() == "true" then
    kong.cache:invalidate(k)
  end

  -- Get raw body
  local raw = kong.request.get_raw_body()
  if not raw or raw == "" then
    return kong.response.exit(400, { message = "Empty body" })
  end

  local ok, body = pcall(cjson.decode, raw)
  if not ok then
    return kong.response.exit(400, { message = "Invalid JSON" })
  end

  local field = conf.request_array_field or "a"
  local incoming = body[field]
  if incoming ~= nil and type(incoming) ~= "table" then
    return kong.response.exit(400, { message = "Field '" .. field .. "' must be an array" })
  end

  -- Prepare items to add
  local to_add = {}
  if type(incoming) == "table" then
    for _, v in ipairs(incoming) do
      if v ~= nil and v ~= cjson.null then
        to_add[#to_add+1] = v -- preserve table or primitive
      end
    end
  end
  if conf.deduplicate ~= false then
    to_add = dedup(to_add)
  end

  -- If skipping history, just forward new items
  if skip_history and skip_history:lower() == "true" then
    body[field] = to_add
    local new_body = cjson.encode(body)
    kong.service.request.set_raw_body(new_body)
    return
  end

  -- Otherwise, fetch current cache
  local current, err = kong.cache:get(k, { ttl = conf.cache_ttl or 3600 }, load_or_init_with({}))
  if err then
    return kong.response.exit(502, { message = "cache get error" })
  end
  if type(current) ~= "table" then
    current = {}
  end

  -- Merge new values into cached list
  for _, v in ipairs(to_add) do
    current[#current+1] = v
  end
  if conf.deduplicate ~= false then
    current = dedup(current)
  end
  current = clamp(current, conf.max_items or 1000)

  -- Overwrite cache for this apikey
  kong.cache:invalidate(k)
  local updated, err2 = kong.cache:get(k, { ttl = conf.cache_ttl or 3600 }, load_or_init_with(current))
  if err2 then
    return kong.response.exit(502, { message = "cache update error" })
  end

  -- Decide what to forward
  if (conf.forward_mode or "full") == "full" then
    body[field] = updated
  else
    body[field] = to_add
  end

  -- Replace body
  local new_body = cjson.encode(body)
  kong.service.request.set_raw_body(new_body)
end

return PLUGIN
