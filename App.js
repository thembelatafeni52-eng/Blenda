import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

export default function App() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Blenda</Text>
      <Text style={styles.slogan}>Have a bright future</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0D1B2A', // dark blue theme
    alignItems: 'center',
    justifyContent: 'center'
  },
  title: {
    fontSize: 40,
    fontWeight: 'bold',
    color: '#00A8E8'
  },
  slogan: {
    fontSize: 18,
    color: '#E0E1DD',
    marginTop: 10
  }
});