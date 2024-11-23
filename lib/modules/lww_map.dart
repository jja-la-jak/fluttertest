import 'lww_register.dart';

class LWWMap<T> {
  final String id;
  final Map<String, LWWRegister<T?>> _data = {};

  LWWMap(this.id, Map<String, dynamic> state) {
    // 초기 상태의 각 키에 대해 새 레지스터를 생성합니다.
    state.forEach((key, register) {
      _data[key] = LWWRegister(id, register);
    });
  }

  Map<String, T?> get value {
    final value = <String, T?>{};
    // 각 값이 해당 키의 레지스터 값으로 설정된 객체를 구축합니다.
    _data.forEach((key, register) {
      if (register.value != null) value[key] = register.value;
    });
    return value;
  }

  Map<String, dynamic> get state {
    final state = <String, dynamic>{};
    // 각 값이 해당 키에서 레지스터의 전체 상태로 설정된 객체를 구축합니다.
    _data.forEach((key, register) {
      state[key] = register.state;
    });
    return state;
  }

  bool has(String key) {
    return _data[key]?.value != null;
  }

  T? get(String key) {
    return _data[key]?.value;
  }

  void set(String key, T value) {
    // 주어진 키에서 레지스터를 가져옵니다
    final register = _data[key];
    // 레지스터가 이미 존재하면 값을 설정합니다.
    if (register != null) {
      register.set(value);
    } else {
      // 그렇지 않으면 값으로 새 `LWWRegister`를 인스턴스화합니다.
      _data[key] = LWWRegister(id, [id, 1, value]);
    }
  }

  void delete(String key) {
    // register가 존재하는 경우 null로 처리
    _data[key]?.set(null);
  }

  void merge(Map<String, dynamic> state) {
    // 각 키의 레지스터를 해당 키의 수신 상태와 재귀적으로 병합합니다.
    state.forEach((key, remote) {
      final local = _data[key];
      // 레지스터가 이미 존재하면 들어오는 상태와 병합합니다.
      if (local != null) {
        local.merge(remote);
      } else {
        // 그렇지 않으면, 들어오는 상태와 함께 새로운 `LWWRegister`를 인스턴스화합니다.
        _data[key] = LWWRegister(id, remote);
      }
    });
  }
}

