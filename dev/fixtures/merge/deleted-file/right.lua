function greet(name)
  if not name then
    return "Hello, stranger"
  end
  return "Hello, " .. name .. "!"
end

function farewell(name)
  return "See you later, " .. name
end

function format_message(msg)
  local timestamp = os.date("%H:%M:%S")
  return "[" .. timestamp .. "] " .. msg
end

return {
  greet = greet,
  farewell = farewell,
  format_message = format_message,
}
