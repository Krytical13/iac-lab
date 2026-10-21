{{- /* vault/agent/cert.tpl: certificate + chain to the destination, key written beside it.
       pkiCert re-requests the certificate when it nears expiry (role TTL here: 30 days). */ -}}
{{- with pkiCert "pki_int/issue/homelab" "common_name=myapp.lab.internal" "ttl=720h" -}}
{{ .Cert }}
{{ .CA }}
{{ .Key | writeToFile "local/agent/tls.key" "" "" "0600" }}
{{- end -}}
