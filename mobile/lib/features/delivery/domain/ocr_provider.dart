/// Which cloud vision model reads the delivery note. The actual API key lives
/// on the backend — the client only names a preferred provider, and the server
/// calls it. Gemini is the active provider; Qwen is a reserved slot the backend
/// can wire up later without a mobile change.
enum OcrProvider {
  gemini('gemini'),
  qwen('qwen');

  const OcrProvider(this.wire);

  final String wire;
}

/// Default provider for delivery-note OCR. Gemini is prioritized.
const OcrProvider kDefaultOcrProvider = OcrProvider.gemini;
