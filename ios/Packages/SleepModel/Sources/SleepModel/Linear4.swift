/// 4×4 algebra on row-major arrays. Written out in the same order as `dusk_model/model.py`, so the
/// two give the same numbers to rounding; Accelerate would tie the tests to a Mac.
enum Linear4 {
  static let n = 4

  static func dot(_ a: [Double], _ b: [Double]) -> Double {
    var acc = 0.0
    for i in 0..<n { acc = acc + a[i] * b[i] }
    return acc
  }

  /// Lower factor L with L Lᵀ = m.
  static func cholesky(_ m: [Double]) -> [Double] {
    var l = [Double](repeating: 0, count: n * n)
    for j in 0..<n {
      var s = m[j * n + j]
      for k in 0..<j { s = s - l[j * n + k] * l[j * n + k] }
      l[j * n + j] = s.squareRoot()
      for i in (j + 1)..<n {
        var t = m[i * n + j]
        for k in 0..<j { t = t - l[i * n + k] * l[j * n + k] }
        l[i * n + j] = t / l[j * n + j]
      }
    }
    return l
  }

  /// Solves L x = v.
  static func forward(_ l: [Double], _ v: [Double]) -> [Double] {
    var x = [Double](repeating: 0, count: n)
    for i in 0..<n {
      var s = v[i]
      for k in 0..<i { s = s - l[i * n + k] * x[k] }
      x[i] = s / l[i * n + i]
    }
    return x
  }

  /// Solves Lᵀ x = v.
  static func backward(_ l: [Double], _ v: [Double]) -> [Double] {
    var x = [Double](repeating: 0, count: n)
    for i in stride(from: n - 1, through: 0, by: -1) {
      var s = v[i]
      for k in (i + 1)..<n { s = s - l[k * n + i] * x[k] }
      x[i] = s / l[i * n + i]
    }
    return x
  }
}
