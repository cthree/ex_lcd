use Bitwise

defmodule ElixirLcd do
  @instruction_clear_display 0x01
  @instruction_return_home 0x02

  @instruction_entry_mode_set 0x04
  @ems_increment 0x02 # move cursor to right
  @ems_shift_display 0x01 #scroll screen instead of move cursor

  @instruction_display_control 0x08
  @dc_display_on 0x04
  @dc_cursor_on 0x02
  @dc_blink_on 0x01

  @instruction_cursor_shift 0x10
  @cs_displaymove 0x08
  @cs_moveright 0x04

  @instruction_function_set 0x20
  @fs_8_bit_mode 0x10
  @fs_2_line 0x08
  @fs_5x10_dots 0x04

  @instruction_setcgramaddr 0x40
  @instruction_setddramaddr 0x80

  @lcd_no_backlight 0x00

  @clear_all @instruction_clear_display ||| @instruction_return_home
  @enter_4_bit_mode 0x20

  @lcd_backlight 0b00001000
  @en            0b00000100  # Enable bit
  @rw            0b00000010  # Read/Write bit
  @rs            0b00000001  # Register select bit

  def connect(device, i2c_address) do
    {:ok, pid} = I2c.start_link(device, i2c_address)

    # reset
    write_4_bits(pid, 0x00)
    :timer.sleep 1000
    write_4_bits(pid, @clear_all)
    :timer.sleep 5
    write_4_bits(pid, @enter_4_bit_mode)
    lcd_send(pid, @instruction_function_set ||| @fs_2_line)
    display_control = @dc_display_on
    lcd_send(pid, @instruction_display_control ||| display_control)
    lcd_send(pid, @instruction_clear_display)
    lcd_send(pid, @instruction_entry_mode_set ||| @ems_increment)
    :timer.sleep 20
    {:ok, pid}
  end

  def write_chars(pid, char_list, line) do
    line_command = case line do
      1 -> 0x80
      2 -> 0xC0
      3 -> 0x94
      4 -> 0xD4
    end
    lcd_send(pid, line_command)
    _write_chars(pid, char_list)
  end

  defp _write_chars(_, []), do: nil
  defp _write_chars(pid, [head | tail]) do
    lcd_send(pid, head, @rs)
    _write_chars(pid, tail)
  end

  defp lcd_send(pid, data, mode \\ 0) do
    high = (data &&& 0xf0) ||| mode
    low = ((data <<< 4) &&& 0xf0) ||| mode
    write_4_bits(pid, high)
    write_4_bits(pid, low)
  end

  defp write_4_bits(pid, data) do
    i2c_expander_write(pid, data)
    pulse_enable(pid, data)
  end

  defp pulse_enable(pid, data) do
    i2c_expander_write(pid, data ||| @en)
    :timer.sleep 1
    i2c_expander_write(pid, data &&& ~~~@en)
    :timer.sleep 1
  end

  defp i2c_expander_write(pid, data) do
    data_with_backlight = data ||| @lcd_backlight
    I2c.write(pid, <<data_with_backlight>>)
    :timer.sleep 1
  end
end
