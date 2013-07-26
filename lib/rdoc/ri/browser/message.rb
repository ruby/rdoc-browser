##
# A Message provides message and a prompt for the ri browser

class RDoc::RI::Browser::Message < Curses::Window

  ##
  # Creates a new Message instance that will sit at the bottom line of the
  # screen

  def initialize
    super 1, Curses.cols, Curses.lines - 1, 0

    keypad true
  end

  ##
  # Clears the message window

  def clear
    super

    setpos 0, 0

    noutrefresh
  end

  ##
  # Displays the error +message+ and flashes the screen

  def error message
    clear
    addstr message
    noutrefresh
    Curses.flash
  end

  ##
  # Displays a prompt on the screen and returns the input given

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

  ##
  # Shows the informational +message+ on the screen

  def show message
    clear
    addstr message
    noutrefresh
  end

  def update_size
    move Curses.lines - 1, 0
    resize 1, Curses.cols

    clear
  end

end

