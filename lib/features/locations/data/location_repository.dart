import '../models/location.dart';

abstract class LocationRepository {
  List<Location> getAll();
  Location? getById(String id);
  Location? getByName(String name);
  void save(Location location);
  void delete(String id);
  bool isEmpty();
}
