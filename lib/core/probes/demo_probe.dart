/// What a section is about — the single axis the demo is organised along.
///
/// Deliberately **not** the release that introduced something. Grouping by
/// version made the demo grow a section and a bloc per release, and it asked
/// the reader the wrong question: nobody opens a demo wondering what 4.1
/// shipped, they wonder how caching behaves. The release something came from is
/// a line in the CHANGELOG.
///
/// These themes file *everything* the screen shows — the live features that
/// drive the app as well as the self-contained probes. Two taxonomies would put
/// "Cache Actions" and "the cache is scoped to the caller" in different places
/// on the same screen, which is exactly the sort of split a reader has to hold
/// in their head for no reason.
///
/// [requests] carries no probes: it is where the plain CRUD and envelope
/// features live. A theme with nothing in it simply renders no section.
enum ProbeTheme {
  requests('📥', 'Requests & responses'),
  cache('💾', 'Cache'),
  authUploads('🔐', 'Auth & uploads'),
  errors('⚠️', 'Errors & error codes'),
  retry('🔁', 'Retry'),
  observability('📤', 'Observability');

  const ProbeTheme(this.icon, this.title);

  /// Shown before the section title.
  final String icon;

  /// Section heading on the home screen.
  final String title;

  /// `💾 Cache`
  String get heading => '$icon $title';
}

/// What a probe observed.
///
/// Records what actually happened rather than a pass/fail: a demo that only
/// showed a green tick would prove nothing, since the defects these probes
/// cover all produced a *wrong answer* rather than an error.
class ProbeOutcome {
  const ProbeOutcome({required this.headline, required this.detail});

  /// One-line result, shown in the status bar.
  final String headline;

  /// The supporting evidence — a count, a body, a flag.
  final String detail;
}

/// One runnable demonstration.
///
/// Everything the screen needs to render a button and report its result, so
/// adding a probe means adding one entry to the registry — no new bloc, no new
/// section, no new state class.
class DemoProbe {
  const DemoProbe({
    required this.id,
    required this.theme,
    required this.label,
    required this.run,
  });

  /// Stable identifier, independent of the label.
  ///
  /// Tests key on this, so rewording a button cannot silently un-test it.
  final String id;

  /// Which section the probe appears under.
  final ProbeTheme theme;

  /// Button text.
  final String label;

  /// Runs the demonstration.
  final Future<ProbeOutcome> Function() run;
}
