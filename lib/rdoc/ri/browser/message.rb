class RDoc::RI::Browser::Message < Curses::Window

  def initialize
    super 1, Curses.cols, Curses.lines - 1, 0

    keypad true
  end

  def clear
    setpos 0, 0
    clrtoeol
    noutrefresh
  end

  def error message
    clear
    addstr message
    noutrefresh
    Curses.flash
  end

  def prompt
    clear

    attron Curses::A_BOLD do
      addstr '> '
    end

    Curses.echo

    return getstr
  ensure
    Curses.noecho
    clear
  end

  def show message
    clear
    addstr message
    noutrefresh
  end

end


