class Downsampler {
  const Downsampler._();

  static List<T> limit<T>(List<T> values, {int maxPoints = 350}) {
    if (values.length <= maxPoints) {
      return List<T>.unmodifiable(values);
    }

    final step = (values.length / maxPoints).ceil();
    final sampled = <T>[];
    for (var index = 0; index < values.length; index += step) {
      sampled.add(values[index]);
    }

    if (sampled.isEmpty) {
      return List<T>.unmodifiable(values.take(maxPoints));
    }

    if (sampled.length < maxPoints && sampled.last != values.last) {
      sampled.add(values.last);
    } else if (sampled.last != values.last) {
      sampled[sampled.length - 1] = values.last;
    }

    return List<T>.unmodifiable(sampled);
  }
}
