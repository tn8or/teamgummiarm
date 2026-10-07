# {{ if .IsHome }}{{ site.Title }}{{ else }}{{ .Title }}{{ end }}
{{ with site.Params.description }}{{ if $.IsHome }}
{{ . }}
{{ end }}{{ end }}{{ with .RawContent | strings.TrimSpace }}
{{ . }}
{{ end }}
{{- $pages := .Pages }}{{ if .IsHome }}{{ $pages = where site.RegularPages "Section" "posts" }}{{ end }}
{{- with $pages }}
{{ range . }}- [{{ .Title }}]({{ .Permalink }}){{ if not .Date.IsZero }} ({{ .Date.Format "2006-01-02" }}){{ end }}
{{ end }}{{ end }}
