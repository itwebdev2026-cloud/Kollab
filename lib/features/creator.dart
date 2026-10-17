class Creator {
  final String id, name, username, city, availability;
  final String? photoData;
  final bool isSample;
  final List<String> niches, types;
  final int followers, price;
  final bool verified;
  final double rating;
  const Creator(this.id, this.name, this.username, this.city, this.niches,
      this.types, this.followers, this.price, this.verified, this.rating,
      this.availability,
      {this.photoData, this.isSample = true});
}

class Requirement {
  String? city, niche, type;
  int minFollowers;
  Requirement({this.city, this.niche, this.type, this.minFollowers = 0});
}

/// Weighted match: only criteria the business set are counted.
int matchScore(Creator c, Requirement r) {
  double got = 0, tot = 0;
  void add(double w, double f) {
    tot += w;
    got += w * f;
  }

  if (r.city != null) add(30, c.city == r.city ? 1 : 0);
  if (r.niche != null) add(30, c.niches.contains(r.niche) ? 1 : 0);
  if (r.type != null) add(20, c.types.contains(r.type) ? 1 : 0);
  if (r.minFollowers > 0) {
    final x = (c.followers / r.minFollowers).clamp(0, 1).toDouble();
    add(20, x >= 1 ? 1 : x * x);
  }
  return tot == 0 ? 0 : (got / tot * 100).round();
}

// Replace with Firestore: collection('creators').where('niches', arrayContains: ...)
const sampleCreators = [
  Creator('1', 'Aola Jamir', 'aola.eats', 'Dimapur', ['Food', 'Lifestyle'],
      ['Instagram Reels', 'UGC'], 18400, 6000, true, 4.8, 'Available'),
  Creator('2', 'Temsu Longkumer', 'temsu.frames', 'Kohima',
      ['Food', 'Events'], ['Photography', 'Instagram Reels'], 12100, 4500,
      true, 4.6, 'Open to Offers'),
  Creator('3', 'Rinchen Dorjee', 'rinchen.vlogs', 'Guwahati',
      ['Food', 'Travel'], ['YouTube Videos', 'Instagram Reels'], 46000, 15000,
      true, 4.9, 'Currently Busy'),
  Creator('4', 'Imli Ao', 'imli.styles', 'Dimapur', ['Fashion', 'Beauty'],
      ['Instagram Reels', 'Photography'], 27800, 9000, true, 4.7, 'Available'),
  Creator('5', 'Vikuo Rio', 'vikuo.tech', 'Kohima', ['Technology'],
      ['YouTube Videos', 'Long-form Video'], 14800, 7000, false, 4.4,
      'Available'),
  Creator('6', 'Moa Lotha', 'moa.films', 'Dimapur', ['Events', 'Entertainment'],
      ['Videography', 'Short-form Video'], 9500, 8000, true, 4.6,
      'Open to Offers'),
];
const allNiches = ['Food', 'Fashion', 'Travel', 'Technology', 'Gaming',
  'Lifestyle', 'Beauty', 'Fitness', 'Business', 'Automotive', 'Education',
  'Entertainment', 'Real Estate', 'Finance', 'Events'];
const allTypes = ['Instagram Reels', 'YouTube Videos', 'Photography',
  'Videography', 'Short-form Video', 'Long-form Video', 'Podcasts',
  'Blogging', 'Live Streaming', 'UGC'];
