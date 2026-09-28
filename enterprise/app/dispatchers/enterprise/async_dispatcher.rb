module Enterprise::AsyncDispatcher
  def listeners
    super + [
      CaptainListener.instance,
      DisparadorListener.instance,
      Captain::ReportingEventListener.instance
    ]
  end
end

