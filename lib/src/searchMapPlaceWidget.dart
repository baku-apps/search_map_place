part of search_map_place;

class SearchMapPlaceWidget extends StatefulWidget {
  SearchMapPlaceWidget({
    @required this.apiKey,
    this.placeholder = 'Search',
    this.icon = Icons.cancel,
    this.iconColor = Colors.black,
    this.onSelected,
    this.onSearch,
    this.language = 'en',
    this.location,
    this.radius,
    this.strictBounds = false,
    this.showOnSearchButton = true,
    this.showOnClearSearchButton = true,
    this.onClearSearch,
  }) : assert((location == null && radius == null) ||
            (location != null && radius != null));

  final bool showOnSearchButton;
  final bool showOnClearSearchButton;
  final Function onClearSearch;

  /// API Key of the Google Maps API.
  final String apiKey;

  /// Placeholder text to show when the user has not entered any input.
  final String placeholder;

  /// The callback that is called when one Place is selected by the user.
  final void Function(Place place) onSelected;

  /// The callback that is called when the user taps on the search icon.
  final void Function(Place place) onSearch;

  /// Language used for the autocompletion.
  ///
  /// Check the full list of [supported languages](https://developers.google.com/maps/faq#languagesupport) for the Google Maps API
  final String language;

  /// The point around which you wish to retrieve place information.
  ///
  /// If this value is provided, `radius` must be provided aswell.
  final LatLng location;

  /// The distance (in meters) within which to return place results. Note that setting a radius biases results to the indicated area, but may not fully restrict results to the specified area.
  ///
  /// If this value is provided, `location` must be provided aswell.
  ///
  /// See [Location Biasing and Location Restrict](https://developers.google.com/places/web-service/autocomplete#location_biasing) in the documentation.
  final int radius;

  /// Returns only those places that are strictly within the region defined by location and radius. This is a restriction, rather than a bias, meaning that results outside this region will not be returned even if they match the user input.
  final bool strictBounds;

  /// The icon to show in the search box
  final IconData icon;

  /// The color of the icon to show in the search box
  final Color iconColor;

  @override
  _SearchMapPlaceWidgetState createState() => _SearchMapPlaceWidgetState();
}

class _SearchMapPlaceWidgetState extends State<SearchMapPlaceWidget>
    with SingleTickerProviderStateMixin {
  TextEditingController _textEditingController = TextEditingController();
  AnimationController _animationController;
  // SearchContainer height.
  Animation _containerHeight;
  // Place options opacity.
  Animation _listOpacity;

  List<dynamic> _placePredictions = [];
  Place _selectedPlace;
  Geocoding geocode;

  BehaviorSubject<String> searchSubject;
  StreamSubscription searchSubscription;

  @override
  void initState() {
    _selectedPlace = null;
    _placePredictions = [];
    geocode = Geocoding(apiKey: widget.apiKey, language: widget.language);
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    _containerHeight = Tween<double>(begin: 55, end: 360).animate(
      CurvedAnimation(
        curve: Interval(0.0, 0.5, curve: Curves.easeInOut),
        parent: _animationController,
      ),
    );
    _listOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        curve: Interval(0.5, 1.0, curve: Curves.easeInOut),
        parent: _animationController,
      ),
    );

    searchSubject = BehaviorSubject<String>();
    searchSubscription = searchSubject.stream
        .throttle((_) => TimerStream(true, Duration(milliseconds: 300)))
        .distinct()
        .switchMap((t) => (t.length > 0)
            ? Stream.fromFuture(_autoCompletePlaces(t))
            : Stream.value(List<dynamic>()))
        .asyncMap((predictions) async {
      if (predictions.length > 0) {
        await _animationController.animateTo(0.5);
        setState(() {
          _placePredictions = predictions;
        });
        await _animationController.forward();
      } else {
        await _animationController.animateTo(0.5);
        setState(() {
          _placePredictions = predictions;
        });
        await _animationController.reverse();
      }
    }).listen((_) {},
            onError: (err) => print('SEARCH PLACES ERROR: ${err.toString()}'));

    super.initState();
  }

  @override
  void dispose() {
    searchSubscription.cancel();
    searchSubject.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: MediaQuery.of(context).size.width * 0.9,
        child: _searchContainer(
          child: _searchInput(context),
        ),
      );

  // Widgets
  Widget _searchContainer({Widget child}) {
    return AnimatedBuilder(
        animation: _animationController,
        builder: (context, _) {
          return Container(
            decoration: _containerDecoration(),
            alignment: Alignment.center,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: child,
                ),
                Opacity(
                  opacity: _listOpacity.value,
                  child: Column(
                    children: <Widget>[
                      _placePredictions.length > 0
                          ? SizedBox(height: 10)
                          : SizedBox.shrink(),
                      if (_placePredictions.length > 0)
                        for (var prediction in _placePredictions)
                          _placeOption(Place.fromJSON(prediction, geocode)),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
  }

  Widget _searchInput(BuildContext context) {
    return Center(
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              decoration: _inputStyle(),
              controller: _textEditingController,
              style:
                  TextStyle(fontSize: MediaQuery.of(context).size.width * 0.04),
              onChanged: (value) => searchSubject.add(value),
            ),
          ),
          Container(width: 15),
          IconButton(
            icon: Icon(this.widget.icon,
                color: _placePredictions.length > 0
                    ? this.widget.iconColor
                    : Colors.grey),
            onPressed: (_textEditingController.text.isEmpty)
                ? null
                : () {
                    setState(() {
                      _textEditingController.clear();
                      _placePredictions = [];
                    });

                    if (widget.onClearSearch != null) {
                      widget.onClearSearch();
                    }
                  },
            //widget.onSearch(Place.fromJSON(_selectedPlace, geocode)),
          ),
          // GestureDetector(
          //   child: Icon(this.widget.icon, color: this.widget.iconColor),
          //   onTap: () =>
          //       widget.onSearch(Place.fromJSON(_selectedPlace, geocode)),
          // )
        ],
      ),
    );
  }

  Widget _placeOption(Place prediction) {
    String place = prediction.description;

    return MaterialButton(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      onPressed: () => _selectPlace(prediction),
      child: ListTile(
        title: Text(
          place.length < 45
              ? "$place"
              : "${place.replaceRange(45, place.length, "")} ...",
          style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.04),
          maxLines: 1,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 0,
        ),
      ),
    );
  }

  // Styling
  InputDecoration _inputStyle() {
    return InputDecoration(
      hintText: this.widget.placeholder,
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
    );
  }

  BoxDecoration _containerDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.all(Radius.circular(6.0)),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 10)
      ],
    );
  }

  Future<List<dynamic>> _autoCompletePlaces(String input) async {
    if (input.isEmpty) {
      return List<dynamic>();
    }

    if (input.length > 0) {
      String url =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=${widget.apiKey}&language=${widget.language}";
      if (widget.location != null && widget.radius != null) {
        url +=
            "&location=${widget.location.latitude},${widget.location.longitude}&radius=${widget.radius}";
        if (widget.strictBounds) {
          url += "&strictbounds";
        }
      }
      final response = await http.get(url);
      final json = JSON.jsonDecode(response.body);

      if (json["error_message"] != null) {
        var error = json["error_message"];
        if (error == "This API project is not authorized to use this API.")
          error +=
              " Make sure the Places API is activated on your Google Cloud Platform";
        throw Exception(error);
      } else {
        var predictions = [];
        predictions = json["predictions"];
        return predictions;
      }
    } else {
      return List<dynamic>();
    }
  }

  void _selectPlace(Place prediction) async {
    /// Will be called when a user selects one of the Place options.

    // Sets TextField value to be the location selected
    _textEditingController.value = TextEditingValue(
      text: prediction.description,
    );

    // Makes animation
    await _animationController.animateTo(0.5);
    setState(() {
      _placePredictions = [];
      _selectedPlace = prediction;
    });
    _animationController.reverse();

    // Calls the `onSelected` callback
    widget.onSelected(prediction);
  }
}
