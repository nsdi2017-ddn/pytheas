/**
 * Consume messages from one or more topics in Kafka and make decisions.
 *
 * Author: Shijie Sun
 * Email: septimus145@gmail.com
 * August, 2016
 */

package frontend;

import java.util.*;
import java.util.regex.Pattern;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.io.*;

import scala.Tuple2;

import org.json.JSONObject;
import org.json.JSONArray;

import kafka.serializer.StringDecoder;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;

import org.apache.spark.SparkConf;
import org.apache.spark.rdd.RDD;
import org.apache.spark.api.java.function.*;
import org.apache.spark.api.java.JavaRDD;
import org.apache.spark.api.java.JavaPairRDD;
import org.apache.spark.streaming.api.java.*;
import org.apache.spark.streaming.kafka.*;
import org.apache.spark.streaming.Durations;

// for changing logger config
import org.apache.log4j.Logger;
import org.apache.log4j.Level;



public final class DecisionMaker {

  public final static int processInterval = 2; // seconds

  public static void main(String[] args) throws Exception {
    if (args.length < 3) {
      System.err.println("Usage: DecisionMaker <brokers> <topic-in> <topic-out>\n" +
          "  <brokers> is a list of one or more Kafka brokers\n" +
          "  <topic-in> is the kafka topic to consume from\n" +
          "  <topic-out> is the kafka topic to publish the decision to\n");
      System.exit(1);
    }

    Logger.getLogger("org").setLevel(Level.OFF);
    Logger.getLogger("akka").setLevel(Level.OFF);

    // parse the arguments
    final String brokers = args[0];
    String topicIn = args[1];
    final String topicOut = args[2];
    // final double gamma = Double.parseDouble(args[3]);
    // final int precisionTime = Integer.parseInt(args[4]);

    // setup producer
    final Properties producerProps = new Properties();
    producerProps.put("bootstrap.servers", brokers);
    producerProps.put("acks", "all");
    producerProps.put("retries", 0);
    producerProps.put("batch.size", 16384);
    producerProps.put("linger.ms", 1);
    producerProps.put("buffer.memory", 33554432);
    producerProps.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
    producerProps.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

    // Create context with `processInterval` batch interval
    SparkConf sparkConf = new SparkConf().setAppName("DicisionMaker");
    final JavaStreamingContext jssc = new JavaStreamingContext(sparkConf, Durations.seconds(processInterval));

    // Create direct kafka stream with brokers and topic
    Set<String> topicSet = new HashSet<>(Arrays.asList(topicIn));
    Map<String, String> kafkaParams = new HashMap<>();
    kafkaParams.put("metadata.broker.list", brokers);
    JavaPairInputDStream<String, String> messages = KafkaUtils.createDirectStream(
        jssc,
        String.class,
        String.class,
        StringDecoder.class,
        StringDecoder.class,
        kafkaParams,
        topicSet
    );

    // create a class to restore the history data
    final HistoryData historyData = new HistoryData(jssc);

    // map to pair to retrieve the data and group_id
    // then reduce by key to combine the performance of each batch
    JavaPairDStream<String, Map<String, List<Double>>> batchQualitySums = messages.mapToPair(
        // extract info of each update
        new PairFunction<Tuple2<String, String>, String, List<Double>>() {
            @Override
            public Tuple2<String, List<Double>> call(Tuple2<String, String> tuple2) {
                JSONObject jObject = new JSONObject(tuple2._2().trim());
                String group_id = jObject.getString("group_id");
                String[] updates = jObject.getString("update").split("\t");
                String decision = updates[0];
                // reverse the score because higher score should represent better performance
                double score = 0 - Double.parseDouble(updates[1]);
                List<Double> scores = new ArrayList<Double>();
                scores.add(score);
                return new Tuple2<>(group_id + ":" + decision, scores);
            }
        // count quantity and total score for (group_id:decision)
        }).reduceByKey(
            new Function2<List<Double>, List<Double>, List<Double>>() {
                @Override
                public List<Double> call(List<Double> m1, List<Double> m2) {
                    m1.addAll(m2);
                    return m1;
                }
        // split the group_id and decision
        }).mapToPair(
            new PairFunction<Tuple2<String, List<Double>>, String, Map<String, List<Double>>>() {
                @Override
                public Tuple2<String, Map<String, List<Double>>>
                        call(Tuple2<String, List<Double>> tuple2) {
                    String group_id = tuple2._1().split(":")[0];
                    String decision = tuple2._1().split(":")[1];
                    Map<String, List<Double>> info = new HashMap<String, List<Double>>();
                    info.put(decision, tuple2._2());
                    return new Tuple2<>(group_id, info);
                }
        });

    // reduce the batchQualitySums
    JavaPairDStream<String, Map<String, List<Double>>> qualitySums;
    Function2<Map<String, List<Double>>, Map<String, List<Double>>,
            Map<String, List<Double>>> qualitySumsReduceFunction2 = new Function2<
            Map<String, List<Double>>, Map<String, List<Double>>, Map<String, List<Double>>>() {
        @Override
        public Map<String, List<Double>> call(Map<String, List<Double>> m1,
                Map<String, List<Double>> m2) {
            // Because has reduced once, so here just merge maps by union
            for (Map.Entry<String, List<Double>> m1Entry : m1.entrySet()) {
                m2.put(m1Entry.getKey(), m1Entry.getValue());
            }
            return m2;
        }
    };
    if (historyData.windowSize > processInterval) {
        qualitySums = batchQualitySums.reduceByKeyAndWindow(qualitySumsReduceFunction2,
                Durations.seconds(historyData.windowSize), Durations.seconds(processInterval));
    } else {
        qualitySums = batchQualitySums.reduceByKey(qualitySumsReduceFunction2);
    }

    // combine the old data with new data and send the decision to kafka
    qualitySums.foreachRDD(new VoidFunction<JavaPairRDD<String, Map<String, List<Double>>>>() {
        // foreachRDD will get RDD of each batch of dstream
        @Override
        public void call(JavaPairRDD<String, Map<String, List<Double>>> groups) throws Exception {
            //System.out.println(groups.cogroup(historyPairDResult).collect());

            // combine old data with new data: cogroup then map
            JavaPairRDD<String, Map<String, List<Double>>> combinedData = groups.cogroup(
                    historyData.pairDData).mapToPair(
                    new PairFunction<Tuple2<String, Tuple2<
                    Iterable<Map<String, List<Double>>>, Iterable<Map<String, List<Double>>>
                    >>, String, Map<String, List<Double>>>() {
                @Override
                public Tuple2<String, Map<String, List<Double>>> call(Tuple2<String, Tuple2<
                        Iterable<Map<String, List<Double>>>, Iterable<Map<String, List<Double>>>
                        >> tuple2) {
                    return historyData.combineCall(tuple2);
                }
            });
            historyData.updateData(combinedData);

            // to show the combined result clearly
            //System.out.println(combinedResult.collect());
            List<Tuple2<String, Map<String, List<Double>>>> collectedData = combinedData.collect();
            Tuple2<String, Map<String, List<Double>>> tmpTuple2 = null;
            Map<String, List<Double>> tmpMap = null;
            for (int i = 0; i < collectedData.size(); i++) {
                tmpTuple2 = collectedData.get(i);
                System.out.println(tmpTuple2._1() + "----");
                tmpMap = tmpTuple2._2();
                for (Map.Entry<String, List<Double>> entry : tmpMap.entrySet()) {
                    System.out.printf("\t%s : (%f, %f) : %f\n", entry.getKey(), entry.getValue().get(0),
                            entry.getValue().get(1), entry.getValue().get(0)/entry.getValue().get(1));
                }
            }

            combinedData.foreachPartition(
                    new VoidFunction<Iterator<Tuple2<String, Map<String, List<Double>>>>> () {
                @Override
                public void call(Iterator<Tuple2<String, Map<String, List<Double>>>> group_iter)
                        throws Exception {
                    KafkaProducer<String, String> kproducer = new KafkaProducer<String, String>(producerProps);
                    Tuple2<String, Map<String, List<Double>>> group = null;
                    while (group_iter.hasNext()) {
                        group = group_iter.next();
                        Map<String, List<Double>> duplicateMap = new HashMap<String, List<Double>>();
                        for (Map.Entry<String, List<Double>> entry : group._2().entrySet()) {
                            List<Double> tmpList = new ArrayList<Double>();
                            for (Double score : entry.getValue())
                                tmpList.add(score.doubleValue());
                            duplicateMap.put(entry.getKey(), tmpList);
                        }
                        String decisions = historyData.getDecision(duplicateMap);
                        ProducerRecord<String, String> data = new ProducerRecord<>(topicOut,
                                group._1() + ";" + decisions + ";From: " + brokers);
                        kproducer.send(data);
                    }
            }});
        }});

    // Start the computation
    jssc.start();
    jssc.awaitTermination();
  }
}
