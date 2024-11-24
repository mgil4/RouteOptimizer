import { StatusBar } from 'expo-status-bar';
import React, { useState } from 'react';
import {Button, StyleSheet, Text, View, TextInput, Image} from 'react-native';
import {waitFor} from "@babel/core/lib/gensync-utils/async";


export default function App() {
  const [addressText, setAddressText] = useState('');
  const [cityText, setCityText] = useState('');
  const [codeText, setCodeText] = useState('');
  const [stateText, setStateText] = useState('');
  const [countryText, setCountryText] = useState('');
  let [displayText, setDisplayText] = useState('');
  let [scoreN, setScoreN] = useState('');
  let [stairsNum, setNumStairs] = useState(0);
  let [hasElevator, setHasElevator] = useState(false);
  let [score, setScore] = useState(7);
  let [imageLink, setLink] = useState('');
  const handleAddressChange = (text) => {
    setAddressText(text);
  };
  const handleCityChange = (text) => {
    setCityText(text);
  };
  const handleCodeChange = (text) => {
    setCodeText(text);
  };
  const handleStateChange = (text) => {
    setStateText(text);
  };
  const handleCountryChange = (text) => {
    setCountryText(text);
  };
  const handleImageLink = (text) => {
    setLink(text);
  };

  const getLatLonFromLocation = (location) => {
    console.log(location);
    const { street_address, city, postal_code, state, country } = location.location;
    const address = `${street_address}, ${city}, ${postal_code}, ${state}, ${country}`;
    const geocode_key = 'eb043604731044e1a72e47936d0f0c47';
    const geocode_url = `https://api.opencagedata.com/geocode/v1/json?q=${address}&key=${geocode_key}`;
  
    return fetch(geocode_url)
      .then(response => response.json())
      .then(data => {
        const lat = data.results[0].geometry.lat;
        const lon = data.results[0].geometry.lng;
        return { lat, lon };
      });
  };

  const getDataFromLatLon = async (overpassQuery) => {
    return fetch('https://overpass-api.de/api/interpreter', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: `data=${encodeURIComponent(overpassQuery)}`,
    })
    .then(response => response.json())
    .then(data => {
      return data.elements.length;
    });
  };

  const getMediaList = async (location) => {
    const api_url = 'https://intelligence.restb.ai/v1/search/comparables?client_key=8aea16ffd5b8c063504c71d62870abd980fa001c70d530fe6c33345bfdfb8191';
    return fetch(api_url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(location)
      })
    .then(response => response.json())
    .then(data => {
      return data.response.comparables[0].media;
    }).catch(error => {
      console.log(location);
      console.error('Error fetching data from the API:', error);
    });
  }

  const getDataFromImg = async (imageUrl) => {
    const vision_url = 'https://api-us.restb.ai/vision/v2/multipredict?client_key=8aea16ffd5b8c063504c71d62870abd980fa001c70d530fe6c33345bfdfb8191&model_id=re_features_v5,re_roomtype_global_v2&image_url='+imageUrl;
    const test = 'https://api-us.restb.ai/vision/v2/multipredict?client_key=8aea16ffd5b8c063504c71d62870abd980fa001c70d530fe6c33345bfdfb8191&model_id=re_features_v5,re_roomtype_global_v2&image_url=https://www.iberdrola.com/documents/20125/40759/elevator_746x419.jpg/9c929186-1f87-1a5c-b009-553b0a004ed7?t=1627624814432';
    return fetch(vision_url, {
        method: 'GET'
    })
    .then(response => {return response.json()});
  }

  const handleButtonPress = async () => {
    const location = {
      "location": {
        "street_address": addressText.trim() === '' ? '552 51st Ave' : addressText,
        "city": cityText.trim() === '' ? 'NY' : cityText,
        "postal_code": codeText.trim() === '' ? '11101' : codeText,
        "state": stateText.trim() === '' ? 'NY' : stateText,
        "country": countryText.trim() === '' ? 'US' : countryText
      } 
    };

    const { lat, lon } = await getLatLonFromLocation(location);
    //const lat = '32.7175991';
    //const lon = '-96.7981047'
    console.log(location);
    console.log(`Latitude: ${lat}, Longitude: ${lon}`);


    const overpassTemplate = `[out:json];(QUESTION(around:1000,${lat},${lon}););out;`;
    let overpassQuery = overpassTemplate.replace('QUESTION', 'node["public_transport"]');
    const busCount = await getDataFromLatLon(overpassQuery);
    console.log(busCount);
    overpassQuery = overpassTemplate.replace('QUESTION', 'node["public_transport"]["wheelchair"="yes"]');
    const busEasyCount = await getDataFromLatLon(overpassQuery);
    console.log(busEasyCount);
    overpassQuery = overpassTemplate.replace('QUESTION', 'way["highway"="footway"]');
    const footwayCount = await getDataFromLatLon(overpassQuery);
    console.log(footwayCount);
    overpassQuery = overpassTemplate.replace('QUESTION', 'way["highway"="path"]');
    const pathCount = await getDataFromLatLon(overpassQuery);
    console.log(pathCount);
    overpassQuery = overpassTemplate.replace('QUESTION', 'way["kerb"="yes"]');
    const kerbCount = await getDataFromLatLon(overpassQuery);
    console.log(kerbCount);
    overpassQuery = overpassTemplate.replace('QUESTION', 'way["kerb:ramp"="path"]');
    const kerbRampCount = await getDataFromLatLon(overpassQuery);
    console.log(kerbRampCount);
    overpassQuery = overpassTemplate.replace('QUESTION', 'way["highway"="crossing"]');
    const crossingCount = await getDataFromLatLon(overpassQuery);
    console.log(crossingCount);

    const mediaList = await getMediaList(location);
    console.log("Control first POST\n"+mediaList);
      score = 7;
      stairsNum = 0;
      hasElevator = false;
    // Iterate through each image URL in the 'media' array
    for (const mediaItem of mediaList) {
        const imageUrl = mediaItem.image_url;
        console.log("Url of image\n"+imageUrl);

        const data2 = await getDataFromImg(imageUrl);
        console.log(data2);
        
        const listPredictions = data2.response?.solutions.re_roomtype_global_v2.predictions;
        for(const predictItem of listPredictions){
            console.log(predictItem.label+" "+predictItem.confidence+" Stairs: "+stairsNum);

            if(predictItem.label=='stairs' && predictItem.confidence > 0.7) setNumStairs(stairsNum+1);
            console.log("Stairs: "+stairsNum);
        }

        const listDetections = data2.response?.solutions.re_features_v5.detections;
        for (const item of listDetections){
            console.log(item.label);
            if(item.label == "elevator"){
                hasElevator =true;
                console.log("Elevator detected");
                break;
            }
        }
        // You can perform further actions with each image URL here
    }
      if(hasElevator){
          if(stairsNum > 3){
              if((score + 2.5 -3*stairsNum)>10) score = 10;
              else if((score + 2.5 -3*stairsNum)<0) score = 0;
              else score += 2.5 -3*stairsNum;
          }
          else{
              if((score + 3.5 -3*stairsNum) > 10) score = 10;
              else if((score + 3.5 -3*stairsNum)<0) score = 0;
              else score += 3.5 -3*stairsNum;
          }
      }
      else{
          if((score -3*stairsNum)>10) score = 10;
          else if((score -3*stairsNum)<0) score = 0;
          else score += -3*stairsNum;
      }
      console.log(score);
      setDisplayText(score);

      let footwayVar = footwayCount/2000;
      console.log(footwayCount+" "+footwayVar);
      let pathVar = pathCount/12;
      console.log(pathCount+" "+pathVar);
      let busVar = busCount/250;
      console.log(busCount+" "+busVar);
      let busEasy = busEasyCount/50;
      console.log(busEasyCount+" "+busEasy);
      let scoreNeighborhood = (footwayVar*0.38 + pathVar*0.2 + busVar*0.1386 + busEasy*0.2814)*10;
      console.log(scoreNeighborhood);
      setScoreN(scoreNeighborhood);
  };

  const handleLinkButton = async () =>{
      const data2 = await getDataFromImg(imageLink);
      console.log(data2);

      score = 7;
      stairsNum = 0;
      hasElevator = false;

      const listPredictions = data2.response?.solutions.re_roomtype_global_v2.predictions;
      for(const predictItem of listPredictions){
          console.log(predictItem.label+" "+predictItem.confidence+" Stairs: "+stairsNum);
          if(predictItem.label=='stairs' && predictItem.confidence > 0.7) stairsNum++;
          console.log("Stairs: "+stairsNum);
      }

      const listDetections = data2.response?.solutions.re_features_v5.detections;
      for (const item of listDetections){
          console.log(item.label);
          if(item.label == 'elevator'){
              hasElevator= true;
              console.log("Elevator detected");
              break;
          }
      }
      if(hasElevator){
          if(stairsNum > 3){
              if((score + 2.5 -3*stairsNum)>10) score = 10;
              else if((score + 2.5 -3*stairsNum)<0) score = 0;
              else score += 2.5 -3*stairsNum;
          }
          else{
              if((score + 3.5 -3*stairsNum) > 10) score = 10;
              else if((score + 3.5 -3*stairsNum)<0) score = 0;
              else score += 3.5 -3*stairsNum;
          }
      }
      else{
          if((score -3*stairsNum)>10) score = 10;
          else if((score -3*stairsNum)<0) score = 0;
          else score += -3*stairsNum;
      }
      console.log(score);
      setDisplayText(score);
  };

  return (
    <View style={styles.container}>
      
      <Image
      source={require('./assets/insdo.png')}  
      style={styles.imageStyle} />

      <Text style={styles.welcomeText}>{"Benvingut al Optimitzador de\nPlanificació de Rutes"}</Text>
      <StatusBar style="auto" />
      <Text style={styles.Text2}>{"Per trobar la ruta de menor cost possible entre origen i destí,\nsiusplau introdueix les coordenades d'aquests punts"}:</Text>
      <Text style={styles.Text4}>Afegeix informació del INICI:</Text>

      <TextInput
        style={styles.input}
        placeholder="Escriu aquí la coordenada X..."
        onChangeText={handleAddressChange}
        value={addressText}
      />
      <TextInput
        style={styles.input}
        placeholder="Escriu aquí la coordenada Y..."
        onChangeText={handleAddressChange}
        value={cityText}
      />
      <Text style={styles.Text}>Afegeix informació del DESTÍ:</Text>

      <TextInput
        style={styles.input}
        placeholder="Escriu aquí la coordenada X..."
        onChangeText={handleAddressChange}
        value={codeText}
      />
      <TextInput
        style={styles.input}
        placeholder="Escriu aquí la coordenada Y..."
        onChangeText={handleAddressChange}
        value={stateText}
      />
      <Text style={styles.Text2}>{""}:</Text>

      <Button 
        style={styles.customButton}
        title="BUSCAR RUTA" 
        onPress={handleButtonPress}
        color="deepskyblue"
       />
        {displayText !== '' && <Text style={styles.resultText}>Home score: {displayText}</Text>}
        {scoreN !== '' && <Text style={styles.resultText}>Neighborhood score: {scoreN}</Text>}
      <Text style={styles.Text3}>       </Text>

    </View>
  );
}
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  input: {
    borderWidth: 1,
    borderColor: 'gray',
    color: 'gray',
    padding: 7,
    margin: 5,
    width: '60%',
  },
  imageStyle: {
    width: 400,
    height: 100,
    marginVertical: 0,
  },
  customButton: {
    backgroundColor: 'orange',
    borderRadius: 75, 
    padding: 10,
    margin: 85,
  },
  buttonText: {
    fontSize: 20,
    color: 'white',
    textAlign: 'center',
  },
  welcomeText: {
    fontSize: 24, 
    color: 'orange',
    fontWeight: 'bold',
    textAlign: 'center', 
    marginVertical: 0,
  },
  Text3: {
    fontSize: 24, 
    marginVertical: 5,
    color: 'white',
  },
  Text: {
    fontSize: 20, 
    color: 'lightgreen',
    fontWeight: 'bold', 
    marginVertical: 10,
  },
  Text4: {
    fontSize: 20, 
    color: 'magenta',
    fontWeight: 'bold', 
    marginVertical: 10,
  },
  Text2: {
    fontSize: 15, 
    color: 'grey', 
    marginVertical: 10,
    maxWidth: '80%', 
    textAlign: 'center', 
  },
  resultText: {
    marginVertical: 20, 
  },
  
});