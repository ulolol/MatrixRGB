package main

import (
	"bufio"
	"fmt"
	"math"
	"math/rand"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"
	"unsafe"
)

const (
	defaultSpeed   = 5
	defaultDensity = 80
	rainbowFreq    = 0.1
	rainbowCycle   = 63

	minTermHeight = 10
	minTermWidth  = 20
)

// Katakana characters used in the original Matrix rain effect.
var katakanaChars = []rune{
	'ｱ', 'ｲ', 'ｳ', 'ｴ', 'ｵ', 'ｶ', 'ｷ', 'ｸ', 'ｹ', 'ｺ',
	'ｻ', 'ｼ', 'ｽ', 'ｾ', 'ｿ', 'ﾀ', 'ﾁ', 'ﾂ', 'ﾃ', 'ﾄ',
	'ﾅ', 'ﾆ', 'ﾇ', 'ﾈ', 'ﾉ', 'ﾊ', 'ﾋ', 'ﾌ', 'ﾍ', 'ﾎ',
	'ﾏ', 'ﾐ', 'ﾑ', 'ﾒ', 'ﾓ', 'ﾔ', 'ﾕ', 'ﾖ', 'ﾗ', 'ﾘ',
	'ﾘ', 'ﾜ', 'ﾞ', 'ﾟ',
}

type column struct {
	active      bool
	head        int
	gap         int
	length      int
	colorOffset int
	lastChar    rune
}

type winsize struct {
	row    uint16
	col    uint16
	xpixel uint16
	ypixel uint16
}

type config struct {
	speed   int
	density int
}

func main() {
	os.Setenv("LC_ALL", "en_US.UTF-8")
	os.Setenv("LANG", "en_US.UTF-8")

	cfg, showHelp, err := parseArguments(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if showHelp {
		printHelp()
		return
	}

	rand.Seed(time.Now().UnixNano())

	rainbowTable := buildRainbowTable(rainbowFreq, rainbowCycle)
	frameDelay := calculateFrameDelay(cfg.speed)

	width, height := getTerminalSize()
	width, height = clampDimensions(width, height)

	numColumns := calculateColumnCount(width, cfg.density)
	columns := initColumns(numColumns, height, len(rainbowTable))

	writer := bufio.NewWriter(os.Stdout)
	setupTerminal(writer)
	defer restoreTerminal(writer)

	resizeCh := make(chan os.Signal, 1)
	signal.Notify(resizeCh, syscall.SIGWINCH)
	defer signal.Stop(resizeCh)

	interruptCh := make(chan os.Signal, 1)
	signal.Notify(interruptCh, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(interruptCh)

loop:
	for {
		select {
		case <-interruptCh:
			break loop
		default:
		}

		resized := false
		for {
			select {
			case <-resizeCh:
				resized = true
			default:
				goto resizeDone
			}
		}
	resizeDone:
		if resized {
			width, height = getTerminalSize()
			width, height = clampDimensions(width, height)
			numColumns = calculateColumnCount(width, cfg.density)
			columns = initColumns(numColumns, height, len(rainbowTable))
			clearScreen(writer)
			writer.Flush()
		}

		frameStart := time.Now()

		for idx := range columns {
			drawColumnFrame(writer, idx, &columns[idx], height, rainbowTable)
		}

		writer.WriteString("\033[0m")
		writer.Flush()

		elapsed := time.Since(frameStart)
		sleepFor := frameDelay - elapsed
		if sleepFor > 0 {
			time.Sleep(sleepFor)
		}
	}
}

func parseArguments(args []string) (config, bool, error) {
	cfg := config{
		speed:   defaultSpeed,
		density: defaultDensity,
	}

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "-h", "--help":
			return cfg, true, nil
		case "-s", "--speed":
			if i+1 >= len(args) {
				return cfg, false, fmt.Errorf("missing value for %s", arg)
			}
			i++
			value, err := strconv.Atoi(args[i])
			if err != nil || value < 1 || value > 10 {
				return cfg, false, fmt.Errorf("speed must be an integer between 1 and 10")
			}
			cfg.speed = value
		case "-d", "--density":
			if i+1 >= len(args) {
				return cfg, false, fmt.Errorf("missing value for %s", arg)
			}
			i++
			value, err := strconv.Atoi(args[i])
			if err != nil || value < 1 || value > 100 {
				return cfg, false, fmt.Errorf("density must be an integer between 1 and 100")
			}
			cfg.density = value
		default:
			return cfg, false, fmt.Errorf("invalid option: %s", arg)
		}
	}

	return cfg, false, nil
}

func printHelp() {
	fmt.Print(`Matrix Digital Rain - Rainbow Edition
Recreates the falling rain animation from the Matrix movies

USAGE:
  matrix-rain [OPTIONS]

OPTIONS:
  -s SPEED    Animation speed (1-10, default: 5)
              1 = slow, 10 = fast
  -d DENSITY  Column density (1-100%, default: 80)
              Percentage of terminal width filled with columns
  -h          Show this help message

EXAMPLES:
  matrix-rain                    # Default settings
  matrix-rain -s 8 -d 100        # Fast animation, full density
  matrix-rain -s 2 -d 50         # Slow animation, sparse

CONTROLS:
  Ctrl+C      Stop the animation
`)
}

func calculateFrameDelay(speed int) time.Duration {
	ms := 160 - speed*12
	if ms < 20 {
		ms = 20
	}
	return time.Duration(ms) * time.Millisecond
}

func buildRainbowTable(freq float64, cycle int) []string {
	table := make([]string, cycle)
	twoPi := 2 * math.Pi
	for i := 0; i < cycle; i++ {
		r := int(math.Sin(freq*float64(i))*127 + 128)
		g := int(math.Sin(freq*float64(i)+twoPi/3)*127 + 128)
		b := int(math.Sin(freq*float64(i)+2*twoPi/3)*127 + 128)
		table[i] = fmt.Sprintf("%d;%d;%d", r, g, b)
	}
	return table
}

func calculateColumnCount(width, density int) int {
	columns := width * density / 100
	if columns < 1 {
		columns = 1
	}
	if columns > width {
		columns = width
	}
	return columns
}

func initColumns(count, height, rainbowLen int) []column {
	if rainbowLen == 0 {
		rainbowLen = 1
	}

	cols := make([]column, count)
	for idx := range cols {
		cols[idx].gap = rand.Intn(10) + 5
		cols[idx].length = rand.Intn(height/2+1) + 3
		cols[idx].colorOffset = rand.Intn(rainbowLen)
	}
	return cols
}

func drawColumnFrame(writer *bufio.Writer, idx int, col *column, height int, rainbowTable []string) {
	if !col.active {
		if col.gap > 0 {
			col.gap--
			return
		}
		col.active = true
		col.head = 1
	}

	head := col.head
	length := col.length
	colorOffset := col.colorOffset
	prevChar := col.lastChar

	if head >= 1 && head <= height {
		char := katakanaChars[rand.Intn(len(katakanaChars))]
		col.lastChar = char
		color := rainbowColor(rainbowTable, head+colorOffset)
		fmt.Fprintf(writer, "\033[%d;%dH\033[1;38;2;%sm%s", head, idx+1, color, string(char))
	}

	trailPos := head - 1
	if trailPos >= 1 && trailPos <= height && prevChar != 0 {
		color := rainbowColor(rainbowTable, trailPos+colorOffset)
		fmt.Fprintf(writer, "\033[%d;%dH\033[2;38;2;%sm%s", trailPos, idx+1, color, string(prevChar))
	}

	erasePos := head - length
	if erasePos >= 1 && erasePos <= height {
		fmt.Fprintf(writer, "\033[0m\033[%d;%dH ", erasePos, idx+1)
	}

	col.head = head + 1

	if head > height+length {
		col.active = false
		col.head = 0
		col.gap = rand.Intn(10) + 5
		col.length = rand.Intn(height/2+1) + 3
		col.colorOffset = (colorOffset + rand.Intn(len(rainbowTable))) % len(rainbowTable)
		col.lastChar = 0
	}
}

func rainbowColor(table []string, position int) string {
	if len(table) == 0 {
		return "255;255;255"
	}
	index := position % len(table)
	if index < 0 {
		index += len(table)
	}
	return table[index]
}

func clampDimensions(width, height int) (int, int) {
	if width < minTermWidth {
		width = minTermWidth
	}
	if height < minTermHeight {
		height = minTermHeight
	}
	return width, height
}

func getTerminalSize() (int, int) {
	if width, height, ok := ioctlGetWinsize(os.Stdout.Fd()); ok {
		return width, height
	}
	if width, height, ok := ioctlGetWinsize(os.Stdin.Fd()); ok {
		return width, height
	}

	width := 80
	height := 24

	if columns := os.Getenv("COLUMNS"); columns != "" {
		if value, err := strconv.Atoi(columns); err == nil && value > 0 {
			width = value
		}
	}
	if lines := os.Getenv("LINES"); lines != "" {
		if value, err := strconv.Atoi(lines); err == nil && value > 0 {
			height = value
		}
	}
	return width, height
}

func ioctlGetWinsize(fd uintptr) (int, int, bool) {
	ws := &winsize{}
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, fd, uintptr(syscall.TIOCGWINSZ), uintptr(unsafe.Pointer(ws)))
	if errno == 0 && ws.col > 0 && ws.row > 0 {
		return int(ws.col), int(ws.row), true
	}
	return 0, 0, false
}

func setupTerminal(writer *bufio.Writer) {
	writer.WriteString("\033[?1049h")
	writer.WriteString("\033[2J")
	writer.WriteString("\033[?25l")
	writer.WriteString("\033[?7l")
	writer.Flush()
}

func restoreTerminal(writer *bufio.Writer) {
	writer.WriteString("\033[0m")
	writer.WriteString("\033[?25h")
	writer.WriteString("\033[?7h")
	writer.WriteString("\033[?1049l")
	writer.Flush()
}

func clearScreen(writer *bufio.Writer) {
	writer.WriteString("\033[2J\033[H")
}
