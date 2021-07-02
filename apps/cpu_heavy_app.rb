class CpuHeavyApp
  def call(env)
    10.times do |i|
      100000.downto(1) do |j|
        Math.sqrt(j) * i / 0.2
      end
    end

    [200, { "Content-Type" => "text/html" }, ["42"]]
  end
end
