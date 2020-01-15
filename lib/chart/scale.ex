defprotocol Contex.Scale do
  def ticks_domain(scale)
  def ticks_range(scale)
  def domain_to_range_fn(scale)
  def domain_to_range(scale, range_val)
  def get_range(scale)
  def set_range(scale, start, finish)
  def get_formatted_tick(scale, tick_val)
end
