class Object
  def abort_with(text)
    abort text.color(:red).bright
  end

  def exit_with(text)
    puts text.color(:green).bright
    exit
  end
end
