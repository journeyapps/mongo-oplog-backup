# Define Enumerable#sorted?

module Enumerable
  # Sorted in ascending order
  def sorted?
    each_cons(2).all? do |a, b|
      (a <=> b) <= 0
    end
  end

  # Strictly increasing, in other words sorted and unique
  def increasing?
    each_cons(2).all? do |a, b|
      (a <=> b) < 0
    end
  end
end
