function greet(name)
  return "Hello, " .. name
end

function farewell(name)
  return "Goodbye, " .. name
end

function format_message(msg)
  return "[INFO] " .. msg
end

return {
  greet = greet,
  farewell = farewell,
  format_message = format_message,
}
