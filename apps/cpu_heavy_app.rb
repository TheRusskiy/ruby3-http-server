class CpuHeavyApp
  def call(env)
    # this is SLOWER with ractors
    # 10.times do |i|
    #   1000.downto(1) do |j|
    #     Math.sqrt(j) * i / 0.2
    #   end
    # end

    100.times do |i|
      Math.sqrt(23467**2436) * i / 0.2
    end

    [200, { "Content-Type" => "text/html" }, ["42"]]
  end
end
