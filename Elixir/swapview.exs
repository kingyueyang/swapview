#!/usr/bin/env elixir

defmodule SwapView do
  def filesize(size),        do: filesize(size, ~w(B KiB MiB GiB TiB))
  def filesize(size, [h]),   do: "#{size}#{h}"
  def filesize(size, [h|_])  when size < 1100, do: "#{size}#{h}"
  def filesize(size, [_|t]), do: filesize(size / 1024, t)

  def get_swap_for(pid) do
    try do
      comm = System.cmd("cat", ["/proc/#{pid}/cmdline"]) |> elem(0)
          |> String.replace(<<0>>, " ") |> String.strip
      s = File.stream!("/proc/#{pid}/smaps", [:read])
       |> Stream.filter(&String.starts_with?(&1, "Swap:"))
       |> Stream.map(&(&1 |> String.split |> Enum.at(1) |> String.to_integer))
       |> Enum.reduce(0, &+/2)
      {pid, s * 1024, comm}
    rescue
      _ ->
        {:err, pid}
    end
  end


  def get_swap do
    File.ls!("/proc")
 |> Stream.filter(fn pid -> pid =~ ~r/^[0-9]+$/ end)
 |> Stream.map(fn(x) -> Task.async(fn -> get_swap_for(x) end) end)
 |> Stream.map(fn(x) -> Task.await(x) end)
 |> Stream.filter(fn {_, s, _} when s > 0 -> true; _ -> false end)
 |> Enum.sort(fn ({_, s1, _}, {_, s2, _}) -> s1 > s2 end)
  end

  defp format({pid, size, comm}) do
    IO.puts "#{pid |> String.rjust 5} #{size |> String.rjust 9} #{comm}"
  end

  def main do
    result = get_swap
    format {"PID", "SWAP", "COMMAND"}
    result |> Enum.each fn {pid, size, comm} ->
      format {pid, size |> filesize, comm}
    end
    total = result |> Enum.map(fn {_, size, _} -> size end) |> Enum.sum |> filesize
    IO.puts "Total: #{total |> String.rjust 8}"
  end
end

SwapView.main
