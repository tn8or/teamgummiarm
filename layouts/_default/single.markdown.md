# {{ .Title }}
{{ if not .Date.IsZero }}
Published: {{ .Date.Format "2006-01-02" }}
{{ end }}
{{ .RawContent | strings.TrimSpace }}
