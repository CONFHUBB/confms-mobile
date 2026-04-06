import 'package:confms_mobile/models/conference.dart';
import 'package:confms_mobile/services/api_service.dart';

class ConferenceService {
  ConferenceService(this._apiService);

  final ApiService _apiService;

  Future<ConferencePage> getConferences({int page = 0, int size = 20}) async {
    final data = await _apiService.get('/conferences?page=$page&size=$size');
    return ConferencePage.fromJson(data);
  }

  Future<Conference> getConferenceById(int conferenceId) async {
    final data = await _apiService.get('/conferences/$conferenceId');
    return Conference.fromJson(data);
  }
}
