function greet(name)
  if not name then
    return "Hello, stranger"
  end
  return "Hello, " .. name .. "!"
end

function farewell(name)
  return "Goodbye, " .. name
end

function format_message(msg)
  return "[INFO] " .. msg
end

function log(msg)
  print(format_message(msg))
end

return {
  farewell = farewell,
  format_message = format_message,
  log = log,
}
