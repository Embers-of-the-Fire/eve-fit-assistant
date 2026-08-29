use crate::core::error::ChatError;
use crate::core::prompt::SystemPromptContext;

pub const DEFAULT_BASE_URL: &str = "https://api.openai.com/v1";

pub const ANTHROPIC_BASE_URL: &str = "https://api.anthropic.com";

pub const DEEPSEEK_BASE_URL: &str = "https://api.deepseek.com";

/// Default multi-turn depth: how many tool-call roundtrips a single turn may
/// take before rig stops the loop.
pub const DEFAULT_MAX_TURNS: usize = 20;

/// The language of the bundled prompt files (`prompt/**/{en,zh}.prompt`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum PromptLanguage {
    #[default]
    En,
    Zh,
}

impl PromptLanguage {
    /// Resolve from a locale tag ("en", "zh", "zh-CN", ...); anything not
    /// starting with "zh" maps to English.
    pub fn from_locale(locale: &str) -> Self {
        if locale.trim().to_lowercase().starts_with("zh") {
            Self::Zh
        } else {
            Self::En
        }
    }

    /// Pick one of two bundled texts by language.
    pub fn pick(self, en: &'static str, zh: &'static str) -> &'static str {
        match self {
            Self::En => en,
            Self::Zh => zh,
        }
    }
}

/// The prompt fragments bundled for one (provider, language) pair. The
/// section headers and assembly live in [`crate::core::prompt`]; these are
/// only the per-scope content pieces.
pub(crate) struct PromptBundle {
    pub(crate) constraint_system: &'static str,
    pub(crate) constraint_provider: &'static str,
    pub(crate) appendix_provider: &'static str,
}

/// The chat completion provider backing a session.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ChatProviderKind {
    /// Any endpoint speaking the OpenAI Chat Completions API (OpenAI,
    /// OpenRouter, vLLM, Ollama, ...).
    #[default]
    OpenAiCompatible,
    Anthropic,
    DeepSeek,
}

impl ChatProviderKind {
    pub fn default_base_url(&self) -> &'static str {
        match self {
            Self::OpenAiCompatible => DEFAULT_BASE_URL,
            Self::Anthropic => ANTHROPIC_BASE_URL,
            Self::DeepSeek => DEEPSEEK_BASE_URL,
        }
    }

    /// Directory name under `prompt/constraint/provider/` and
    /// `prompt/appendix/provider/` holding this provider's prompt files.
    pub fn prompt_dir(&self) -> &'static str {
        match self {
            Self::OpenAiCompatible => "openai",
            Self::Anthropic => "anthropic",
            Self::DeepSeek => "deepseek",
        }
    }

    pub(crate) fn prompt_bundle(&self, language: PromptLanguage) -> PromptBundle {
        use PromptLanguage::{En, Zh};
        match (*self, language) {
            (Self::OpenAiCompatible, En) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/en.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/openai/en.prompt"
                ),
                appendix_provider: include_str!("../../prompt/appendix/provider/openai/en.prompt"),
            },
            (Self::OpenAiCompatible, Zh) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/zh.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/openai/zh.prompt"
                ),
                appendix_provider: include_str!("../../prompt/appendix/provider/openai/zh.prompt"),
            },
            (Self::Anthropic, En) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/en.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/anthropic/en.prompt"
                ),
                appendix_provider: include_str!(
                    "../../prompt/appendix/provider/anthropic/en.prompt"
                ),
            },
            (Self::Anthropic, Zh) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/zh.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/anthropic/zh.prompt"
                ),
                appendix_provider: include_str!(
                    "../../prompt/appendix/provider/anthropic/zh.prompt"
                ),
            },
            (Self::DeepSeek, En) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/en.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/deepseek/en.prompt"
                ),
                appendix_provider: include_str!(
                    "../../prompt/appendix/provider/deepseek/en.prompt"
                ),
            },
            (Self::DeepSeek, Zh) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/zh.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/deepseek/zh.prompt"
                ),
                appendix_provider: include_str!(
                    "../../prompt/appendix/provider/deepseek/zh.prompt"
                ),
            },
        }
    }
}

/// The proxy URLs and bypass list of a resolved system proxy configuration.
/// The client re-applies this routing to every request — reqwest follows
/// redirects inside the client, so a redirect target is routed on its own:
/// a redirect to a bypassed host goes direct, and a cross-scheme redirect
/// picks up that scheme's proxy instead of reusing the initial URL's.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ProxyConfig {
    /// Proxy URL for `http://` request URLs
    /// (`http://`/`https://[user:password@]host:port`), if configured.
    pub http: Option<String>,
    /// Proxy URL for `https://` request URLs, if configured.
    pub https: Option<String>,
    /// Fallback proxy URL covering both schemes, if configured.
    pub all: Option<String>,
    /// Hosts reached directly, in the `no_proxy` / GNOME `ignore-hosts`
    /// formats (`*`, domain suffixes, exact IPs, CIDR ranges, optional
    /// `:port` qualifiers) — see `system_proxy.dart` on the Dart side.
    pub bypass: Vec<String>,
}

/// How requests to the provider endpoint are routed, resolved by the host
/// app from the desktop system proxy settings. Ignored on wasm (the browser
/// applies its own proxy).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub enum ProxyRouting {
    /// No host-side routing decision: the caller keeps the default reqwest
    /// client, which honors the standard proxy environment variables.
    #[default]
    Default,
    /// The host resolved a proxy bypass for the endpoint: connect directly,
    /// ignoring any proxy environment variables.
    Direct,
    /// Route requests through the resolved system proxy configuration; see
    /// [`ProxyConfig`].
    Proxy(ProxyConfig),
}

#[derive(Debug, Clone)]
pub struct ChatProviderConfig {
    pub provider: ChatProviderKind,
    pub api_key: String,
    pub base_url: String,
    pub model: String,
    /// Language of the bundled prompt files; see [`PromptLanguage`].
    pub language: PromptLanguage,
    /// Extra system-prompt sections appended after the rendered bundled
    /// prompt; blank adds nothing.
    pub system_prompt: String,
    /// Multi-turn depth (tool-call roundtrips per turn); see
    /// [`DEFAULT_MAX_TURNS`].
    pub max_turns: usize,
    /// Proxy routing resolved by the host app from the desktop system proxy
    /// settings; see [`ProxyRouting`].
    pub proxy: ProxyRouting,
}

impl ChatProviderConfig {
    /// A blank `base_url` selects the provider's default endpoint.
    pub fn new(
        provider: ChatProviderKind,
        api_key: impl Into<String>,
        base_url: impl Into<String>,
        model: impl Into<String>,
    ) -> Result<Self, ChatError> {
        let config = Self {
            provider,
            api_key: api_key.into(),
            base_url: base_url.into(),
            model: model.into(),
            language: PromptLanguage::default(),
            system_prompt: String::new(),
            max_turns: DEFAULT_MAX_TURNS,
            proxy: ProxyRouting::default(),
        };
        config.validate()?;
        Ok(config)
    }

    /// Select the language of the bundled prompt files.
    pub fn with_language(mut self, language: PromptLanguage) -> Self {
        self.language = language;
        self
    }

    /// Add extra system-prompt sections appended after the rendered bundled
    /// prompt. Empty or whitespace-only prompts are ignored.
    pub fn with_system_prompt(mut self, system_prompt: impl Into<String>) -> Self {
        let prompt = system_prompt.into();
        if !prompt.trim().is_empty() {
            self.system_prompt = prompt.trim().to_string();
        }
        self
    }

    /// The full system prompt: the bundled sections assembled by
    /// [`crate::core::prompt::render_system_prompt`] according to the
    /// session's actual tool attachments ([context]), plus the configured
    /// extra sections appended last.
    pub fn full_system_prompt(&self, context: &SystemPromptContext) -> String {
        crate::core::prompt::render_system_prompt(self, context)
    }

    /// Override the multi-turn depth. Zero is ignored, keeping the default.
    pub fn with_max_turns(mut self, max_turns: usize) -> Self {
        if max_turns > 0 {
            self.max_turns = max_turns;
        }
        self
    }

    /// Route requests through the given proxy URL
    /// (`http://`/`https://[user:password@]host:port`); an `https://` scheme
    /// keeps the connection to the proxy itself under TLS. The proxy covers
    /// both request schemes with no bypass list; hosts that resolve the
    /// desktop system proxy settings use [`ProxyRouting::Proxy`] with a full
    /// [`ProxyConfig`] instead.
    /// Empty or whitespace-only values are ignored.
    pub fn with_proxy(mut self, proxy: impl Into<String>) -> Self {
        let proxy = proxy.into();
        if !proxy.trim().is_empty() {
            self.proxy = ProxyRouting::Proxy(ProxyConfig {
                all: Some(proxy.trim().to_string()),
                ..ProxyConfig::default()
            });
        }
        self
    }

    /// Connect to the provider endpoint directly, ignoring any proxy
    /// environment variables. Use when the host resolved a proxy bypass for
    /// the endpoint: the default client would re-read `HTTP_PROXY` /
    /// `HTTPS_PROXY` and route a bypassed endpoint through them.
    pub fn with_direct_routing(mut self) -> Self {
        self.proxy = ProxyRouting::Direct;
        self
    }

    /// Build a reqwest client honoring [`Self::proxy`]; `None` means the
    /// caller should keep rig's default client (which reads the standard
    /// proxy environment variables itself). [`ProxyRouting::Direct`] yields
    /// a client with proxying fully disabled.
    pub fn http_client(&self) -> Result<Option<reqwest::Client>, ChatError> {
        build_http_client(&self.proxy)
    }

    /// The configured base URL, or the provider default when blank.
    pub fn resolved_base_url(&self) -> &str {
        if self.base_url.trim().is_empty() {
            self.provider.default_base_url()
        } else {
            self.base_url.trim_end_matches('/')
        }
    }

    pub fn validate(&self) -> Result<(), ChatError> {
        if self.api_key.trim().is_empty() {
            return Err(ChatError::InvalidConfig("api key must not be empty".into()));
        }
        if self.model.trim().is_empty() {
            return Err(ChatError::InvalidConfig("model must not be empty".into()));
        }
        Ok(())
    }
}

/// Build a reqwest client for the given [`ProxyRouting`], or `None` for
/// [`ProxyRouting::Default`] so the caller can keep rig's default client.
/// [`ProxyRouting::Direct`] disables proxying entirely
/// ([`reqwest::ClientBuilder::no_proxy`]): without it the client would fall
/// back to the proxy environment variables, routing a host-bypassed endpoint
/// through a proxy the host explicitly excluded.
/// [`ProxyRouting::Proxy`] routes every request through a per-URL matcher
/// ([`reqwest::Proxy::custom`]) instead of one blanket `Proxy::all`: reqwest
/// follows redirects inside the client, so a redirect to a bypassed host
/// goes direct and a cross-scheme redirect uses that scheme's proxy. The
/// env-var fallback is disabled there too (`no_proxy` before `proxy`) —
/// otherwise a matcher miss (bypassed or unhandled scheme) would fall
/// through to reqwest's automatic system proxy. On wasm the routing is
/// ignored: reqwest goes through browser fetch, which already applies the
/// browser's proxy settings.
pub(crate) fn build_http_client(
    routing: &ProxyRouting,
) -> Result<Option<reqwest::Client>, ChatError> {
    let builder = reqwest::Client::builder();
    #[cfg(not(target_arch = "wasm32"))]
    let builder = match routing {
        ProxyRouting::Default => return Ok(None),
        ProxyRouting::Direct => builder.no_proxy(),
        ProxyRouting::Proxy(config) => {
            let matcher = ProxyMatcher::new(config)?;
            let builder = builder.no_proxy();
            if matcher.has_proxy() {
                builder.proxy(reqwest::Proxy::custom(move |url| matcher.proxy_for(url)))
            } else {
                builder
            }
        }
    };
    #[cfg(target_arch = "wasm32")]
    let _ = routing;
    builder
        .build()
        .map(Some)
        .map_err(|e| ChatError::Client(e.to_string()))
}

/// A [`ProxyConfig`] with its proxy URLs pre-parsed, deciding per request
/// URL — the initial URL and every redirect target alike — which proxy
/// applies, if any.
#[cfg(not(target_arch = "wasm32"))]
struct ProxyMatcher {
    http: Option<reqwest::Url>,
    https: Option<reqwest::Url>,
    all: Option<reqwest::Url>,
    bypass: Vec<String>,
}

#[cfg(not(target_arch = "wasm32"))]
impl ProxyMatcher {
    fn new(config: &ProxyConfig) -> Result<Self, ChatError> {
        fn parse(value: &Option<String>) -> Result<Option<reqwest::Url>, ChatError> {
            match value.as_deref().map(str::trim) {
                None | Some("") => Ok(None),
                // Mirrors the `Proxy::all` parsing: a scheme-less value is
                // retried with an `http://` prefix.
                Some(proxy) => reqwest::Url::parse(proxy)
                    .or_else(|_| reqwest::Url::parse(&format!("http://{proxy}")))
                    .map(Some)
                    .map_err(|e| ChatError::InvalidConfig(format!("invalid proxy url {proxy:?}: {e}"))),
            }
        }
        Ok(Self {
            http: parse(&config.http)?,
            https: parse(&config.https)?,
            all: parse(&config.all)?,
            bypass: config.bypass.clone(),
        })
    }

    fn has_proxy(&self) -> bool {
        self.http.is_some() || self.https.is_some() || self.all.is_some()
    }

    /// The proxy applying to [url], mirroring the Dart host's
    /// `systemProxyRoutingFor`: the bypass list first, then the
    /// scheme-specific proxy with the `all` fallback. A returned URL keeps
    /// its userinfo, which reqwest applies as basic proxy credentials — the
    /// same handling `Proxy::all` gives the custom matcher's result.
    fn proxy_for(&self, url: &reqwest::Url) -> Option<reqwest::Url> {
        if is_bypassed(&self.bypass, url) {
            return None;
        }
        let proxy = match url.scheme() {
            "http" => self.http.as_ref().or(self.all.as_ref()),
            "https" => self.https.as_ref().or(self.all.as_ref()),
            _ => None,
        };
        proxy.cloned()
    }
}

/// Whether [url] matches one bypass entry, mirroring the GNOME
/// `ignore-hosts` semantics the Dart host resolves the list with (see
/// `system_proxy.dart`):
///
/// - `*` matches everything.
/// - A hostname (`example.com`, `.example.com`, or `*.example.com`) matches
///   the host itself and any subdomain of it.
/// - An IPv4 or IPv6 address matches only that exact address; hostname
///   entries never match IP-literal hosts and vice versa.
/// - Any entry may carry a `:port` qualifier (`example.com:80`,
///   `[::1]:443`), restricting the match to URLs using that port.
/// - An IP range in CIDR notation (`127.0.0.0/8`, `fe80::/10`) matches any
///   address within the range.
#[cfg(not(target_arch = "wasm32"))]
fn is_bypassed(bypass: &[String], url: &reqwest::Url) -> bool {
    let host = url.host_str().unwrap_or_default().to_lowercase();
    let host = host.trim_start_matches('[').trim_end_matches(']');
    let host_ip = host.parse::<std::net::IpAddr>().ok();
    let port = url.port_or_known_default().unwrap_or(0);
    bypass
        .iter()
        .any(|raw| bypass_entry_matches(raw, host, host_ip, port))
}

#[cfg(not(target_arch = "wasm32"))]
fn bypass_entry_matches(
    raw: &str,
    host: &str,
    host_ip: Option<std::net::IpAddr>,
    port: u16,
) -> bool {
    use std::net::IpAddr;

    let mut entry = raw.trim().to_lowercase();
    if entry.is_empty() {
        return false;
    }

    // Strip an optional :port qualifier; it restricts the entry to that
    // port. IPv6 literals keep their brackets for the qualifier (`[::1]:443`).
    if entry.starts_with('[') {
        let Some(closing) = entry.find(']') else {
            return false;
        };
        if entry.len() > closing + 1 {
            let entry_port = entry[closing + 1..]
                .strip_prefix(':')
                .and_then(|p| p.parse::<u16>().ok());
            if entry_port != Some(port) {
                return false;
            }
        }
        entry = entry[1..closing].to_string();
    } else if entry.matches(':').count() == 1 {
        let colon = entry.find(':').expect("one colon");
        if let Ok(entry_port) = entry[colon + 1..].parse::<u16>() {
            if entry_port != port {
                return false;
            }
            entry = entry[..colon].to_string();
        }
    }
    if entry == "*" {
        return true;
    }

    // CIDR range: base address plus prefix length (`127.0.0.0/8`).
    if let Some(slash) = entry.find('/') {
        let base = entry[..slash].parse::<IpAddr>().ok();
        let prefix = entry[slash + 1..].parse::<u32>().ok();
        return match (base, prefix, host_ip) {
            (Some(base), Some(prefix), Some(host_ip)) => ip_in_prefix(host_ip, base, prefix),
            _ => false,
        };
    }

    let entry_ip = entry.parse::<IpAddr>().ok();
    if host_ip.is_some() || entry_ip.is_some() {
        // IP entries match only IP-literal hosts, and only exactly; hostname
        // entries never match IP-literal hosts.
        return matches!((host_ip, entry_ip), (Some(h), Some(e)) if h == e);
    }

    let entry = entry
        .strip_prefix("*.")
        .or_else(|| entry.strip_prefix('.'))
        .unwrap_or(&entry);
    match host.strip_suffix(entry) {
        Some(rest) => rest.is_empty() || rest.ends_with('.'),
        None => false,
    }
}

/// Whether the IP [host] lies within [base]/[prefix] (CIDR).
#[cfg(not(target_arch = "wasm32"))]
fn ip_in_prefix(host: std::net::IpAddr, base: std::net::IpAddr, prefix: u32) -> bool {
    use std::net::IpAddr;
    match (host, base) {
        (IpAddr::V4(host), IpAddr::V4(base)) if prefix <= 32 => {
            let mask = if prefix == 0 { 0 } else { u32::MAX << (32 - prefix) };
            u32::from(host) & mask == u32::from(base) & mask
        }
        (IpAddr::V6(host), IpAddr::V6(base)) if prefix <= 128 => {
            let mask = if prefix == 0 { 0 } else { u128::MAX << (128 - prefix) };
            u128::from(host) & mask == u128::from(base) & mask
        }
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn with_proxy_ignores_blank_values() {
        let config =
            ChatProviderConfig::new(ChatProviderKind::OpenAiCompatible, "key", "", "model")
                .unwrap();
        assert_eq!(config.proxy, ProxyRouting::Default);
        let config = config.with_proxy("   ");
        assert_eq!(config.proxy, ProxyRouting::Default);
    }

    #[test]
    fn with_proxy_trims_and_stores() {
        let config =
            ChatProviderConfig::new(ChatProviderKind::OpenAiCompatible, "key", "", "model")
                .unwrap()
                .with_proxy(" http://127.0.0.1:7890 ");
        assert_eq!(
            config.proxy,
            ProxyRouting::Proxy(ProxyConfig {
                all: Some("http://127.0.0.1:7890".into()),
                ..ProxyConfig::default()
            })
        );
    }

    #[cfg(not(target_arch = "wasm32"))]
    #[test]
    fn http_client_builds_only_with_proxy() {
        let config =
            ChatProviderConfig::new(ChatProviderKind::OpenAiCompatible, "key", "", "model")
                .unwrap();
        assert!(config.http_client().unwrap().is_none());
        let config = config.with_proxy("http://127.0.0.1:7890");
        assert!(config.http_client().unwrap().is_some());
    }

    /// A host-resolved proxy bypass must yield an explicit client (with
    /// proxying disabled via `no_proxy`), not `None`: `None` would keep the
    /// default client, which re-reads the proxy environment variables and
    /// could route the bypassed endpoint through them.
    #[cfg(not(target_arch = "wasm32"))]
    #[test]
    fn http_client_builds_proxy_free_client_for_direct_routing() {
        let config =
            ChatProviderConfig::new(ChatProviderKind::OpenAiCompatible, "key", "", "model")
                .unwrap()
                .with_direct_routing();
        assert_eq!(config.proxy, ProxyRouting::Direct);
        assert!(config.http_client().unwrap().is_some());
    }

    #[cfg(not(target_arch = "wasm32"))]
    #[test]
    fn http_client_rejects_invalid_proxy_url() {
        let config =
            ChatProviderConfig::new(ChatProviderKind::OpenAiCompatible, "key", "", "model")
                .unwrap()
                .with_proxy("not a url");
        assert!(matches!(
            config.http_client(),
            Err(ChatError::InvalidConfig(_))
        ));
    }

    /// Regression test for CWE-319: an `https://` proxy URL resolved by the
    /// Dart host must reach `build_http_client` (and thus the reqwest proxy
    /// matcher) unchanged — scheme and embedded credentials included — so
    /// reqwest keeps the TLS connection to the proxy instead of a downgraded
    /// cleartext one.
    #[cfg(not(target_arch = "wasm32"))]
    #[test]
    fn http_client_accepts_https_proxy_with_credentials_unchanged() {
        let config =
            ChatProviderConfig::new(ChatProviderKind::OpenAiCompatible, "key", "", "model")
                .unwrap()
                .with_proxy("https://user:password@proxy.example:443");
        assert_eq!(
            config.proxy,
            ProxyRouting::Proxy(ProxyConfig {
                all: Some("https://user:password@proxy.example:443".into()),
                ..ProxyConfig::default()
            })
        );
        assert!(config.http_client().unwrap().is_some());
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn proxy_for(matcher: &ProxyMatcher, url: &str) -> Option<String> {
        matcher
            .proxy_for(&reqwest::Url::parse(url).unwrap())
            .map(|u| u.to_string())
    }

    /// Scheme-specific routing must survive into the Rust client: a
    /// cross-scheme redirect picks up that scheme's proxy, with `all` as the
    /// fallback, instead of reusing the proxy resolved for the initial URL.
    #[cfg(not(target_arch = "wasm32"))]
    #[test]
    fn proxy_matcher_routes_per_scheme_with_all_fallback() {
        let matcher = ProxyMatcher::new(&ProxyConfig {
            http: Some("http://127.0.0.1:1001".into()),
            https: Some("http://127.0.0.1:1002".into()),
            all: None,
            bypass: vec![],
        })
        .unwrap();
        assert_eq!(
            proxy_for(&matcher, "http://example.com/").as_deref(),
            Some("http://127.0.0.1:1001/")
        );
        assert_eq!(
            proxy_for(&matcher, "https://example.com/").as_deref(),
            Some("http://127.0.0.1:1002/")
        );

        let matcher = ProxyMatcher::new(&ProxyConfig {
            http: None,
            https: Some("http://127.0.0.1:1002".into()),
            all: Some("http://127.0.0.1:1003".into()),
            bypass: vec![],
        })
        .unwrap();
        assert_eq!(
            proxy_for(&matcher, "http://example.com/").as_deref(),
            Some("http://127.0.0.1:1003/")
        );
        assert_eq!(
            proxy_for(&matcher, "https://example.com/").as_deref(),
            Some("http://127.0.0.1:1002/")
        );
    }

    /// The bypass list resolved by the Dart host (GNOME `ignore-hosts`
    /// semantics) must apply to every request URL, not just the initial one.
    #[cfg(not(target_arch = "wasm32"))]
    #[test]
    fn proxy_matcher_honors_bypass_entries() {
        let matcher = ProxyMatcher::new(&ProxyConfig {
            all: Some("http://127.0.0.1:7890".into()),
            bypass: vec![
                "localhost".into(),
                "*.internal.example".into(),
                "10.0.0.0/8".into(),
                "192.0.2.1".into(),
                "127.0.0.1:8080".into(),
            ],
            ..ProxyConfig::default()
        })
        .unwrap();
        let proxied = Some("http://127.0.0.1:7890/");
        // Non-bypassed hosts keep the proxy.
        assert_eq!(
            proxy_for(&matcher, "https://api.openai.com/v1").as_deref(),
            proxied
        );
        // Hostname, subdomain wildcard, CIDR, and exact-IP entries go direct.
        assert_eq!(proxy_for(&matcher, "https://localhost/v1"), None);
        assert_eq!(proxy_for(&matcher, "https://chat.internal.example/"), None);
        assert_eq!(proxy_for(&matcher, "http://10.1.2.3/"), None);
        assert_eq!(proxy_for(&matcher, "http://192.0.2.1/"), None);
        // A hostname entry never matches an IP-literal host, and vice versa.
        assert_eq!(proxy_for(&matcher, "http://127.0.0.2/").as_deref(), proxied);
        // A port-qualified entry matches only that port.
        assert_eq!(proxy_for(&matcher, "http://127.0.0.1:8080/"), None);
        assert_eq!(proxy_for(&matcher, "http://127.0.0.1:9090/").as_deref(), proxied);

        let matcher = ProxyMatcher::new(&ProxyConfig {
            all: Some("http://127.0.0.1:7890".into()),
            bypass: vec!["*".into()],
            ..ProxyConfig::default()
        })
        .unwrap();
        assert_eq!(proxy_for(&matcher, "https://api.openai.com/v1"), None);
    }

    /// Regression test: a proxied URL redirecting to a bypassed URL must
    /// follow the redirect directly, not through the proxy. reqwest follows
    /// redirects inside the client, so routing must be re-evaluated per
    /// request URL (`Proxy::custom`) instead of applying one `Proxy::all`
    /// resolved for the initial URL.
    #[cfg(not(target_arch = "wasm32"))]
    #[tokio::test]
    async fn http_client_follows_redirect_to_bypassed_host_directly() {
        use std::sync::Arc;
        use std::sync::atomic::{AtomicUsize, Ordering};

        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        use tokio::net::{TcpListener, TcpStream};

        async fn read_request_head(socket: &mut TcpStream) {
            let mut buf = [0u8; 4096];
            let mut head = Vec::new();
            loop {
                let n = socket.read(&mut buf).await.unwrap();
                if n == 0 {
                    break;
                }
                head.extend_from_slice(&buf[..n]);
                if head.windows(4).any(|w| w == b"\r\n\r\n") {
                    break;
                }
            }
        }

        // The bypassed redirect target: answers 200 on a direct connection.
        let target = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let target_port = target.local_addr().unwrap().port();
        let target_hits = Arc::new(AtomicUsize::new(0));
        let target_task = tokio::spawn({
            let target_hits = target_hits.clone();
            async move {
                while let Ok((mut socket, _)) = target.accept().await {
                    target_hits.fetch_add(1, Ordering::Relaxed);
                    read_request_head(&mut socket).await;
                    socket
                        .write_all(
                            b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok",
                        )
                        .await
                        .unwrap();
                }
            }
        });

        // The proxy: counts requests and always 302-redirects to the
        // bypassed target. A client re-proxying the redirect loops back
        // here until reqwest's redirect limit errors the request.
        let proxy = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let proxy_port = proxy.local_addr().unwrap().port();
        let proxy_hits = Arc::new(AtomicUsize::new(0));
        let proxy_task = tokio::spawn({
            let proxy_hits = proxy_hits.clone();
            let location = format!("http://127.0.0.1:{target_port}/final");
            async move {
                while let Ok((mut socket, _)) = proxy.accept().await {
                    proxy_hits.fetch_add(1, Ordering::Relaxed);
                    read_request_head(&mut socket).await;
                    let response = format!(
                        "HTTP/1.1 302 Found\r\nLocation: {location}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    );
                    socket.write_all(response.as_bytes()).await.unwrap();
                }
            }
        });

        let routing = ProxyRouting::Proxy(ProxyConfig {
            all: Some(format!("http://127.0.0.1:{proxy_port}")),
            bypass: vec![format!("127.0.0.1:{target_port}")],
            ..ProxyConfig::default()
        });
        let client = build_http_client(&routing).unwrap().unwrap();
        // No server ever listens on the initial URL's host: only the fake
        // proxy answers (with the redirect), without forwarding anywhere.
        let response = client
            .get("http://proxied.efa-chat.invalid/start")
            .send()
            .await
            .unwrap();
        assert_eq!(response.status(), reqwest::StatusCode::OK);
        assert_eq!(response.text().await.unwrap(), "ok");
        assert_eq!(proxy_hits.load(Ordering::Relaxed), 1);
        assert_eq!(target_hits.load(Ordering::Relaxed), 1);
        proxy_task.abort();
        target_task.abort();
    }
}
