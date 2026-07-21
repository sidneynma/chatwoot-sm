module Enterprise::AsyncDispatcher
  def listeners
    super + [
      CaptainListener.instance,
      DisparadorListener.instance
    ]
  end
end

