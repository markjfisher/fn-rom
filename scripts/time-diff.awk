{
    split($2, t, /[:.]/)
    ms = (((t[1] * 60) + t[2]) * 60 + t[3]) * 1000 + t[4]
    if (prev_ms != "") {
        print ms - prev_ms
    }
    prev_ms = ms
}
