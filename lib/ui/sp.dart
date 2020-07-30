import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Sp extends StatefulWidget {
  @override
  _SpState createState() => _SpState();
}

class _SpState extends State<Sp> {
  @override
  Widget build(BuildContext context) {

    Size size = MediaQuery.of(context).size;
    return SafeArea(
      child: Scaffold(
        appBar:AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: InkWell(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.keyboard_arrow_left,
              color: Colors.black,
              size: 62,
            ),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: <Widget>[
            Center(
              child: Image.asset(
                'assets/sp.png',
                fit: BoxFit.fitHeight,
                width: size.width,
                height: size.height,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Card(
                  margin: EdgeInsets.all(0.0),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4,
                  color: Color(0x99000000),
                  child: Container(
                    height: size.height * 0.50,
                    padding: EdgeInsets.symmetric(vertical:8.0, horizontal: 4.0),
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: <Widget>[
                                  Text(
                                  "Sabbathprograms.com",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ]
                              ),


                              SizedBox(
                                height: 8,
                              ),

                              SizedBox(
                                width: size.width - 10,
                                height: size.height*0.5 - 115,
                                child: AutoSizeText(
                                  "Sabbath Programs is an initiative to improve the "
                                      "quality of church services by providing Christ-centered,"
                                      " creative and purpose-driven programs to congregations "
                                      "across the world. We provide innovative programs for Sabbath School, "
                                      "Divine Service and Adventist Youth (AY).",
                                  style: TextStyle(
                                    fontSize: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(),
                        ),

                        Divider(
                          color: Colors.grey[200],
                        ),
                        InkWell(
                          onTap: () => _launchWeb(),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                              border: Border.all(color: Colors.grey),
                              color: Colors.red
                            ),
                            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
                            child: Center(
                              child: Text(
                                "Visit the Website!",
                                style: TextStyle(
                                    fontSize: 18,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ),
                        ),
                        ],
                    ),
                  )
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  _launchWeb() async {
    const url = 'https://sabbathprograms.com/weekly';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
