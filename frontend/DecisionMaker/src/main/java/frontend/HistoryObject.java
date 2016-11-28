package frontend;

import java.util.*;
import java.io.Serializable;

import scala.Tuple2;

import org.apache.spark.api.java.JavaRDD;
import org.apache.spark.api.java.JavaPairRDD;
import org.apache.spark.streaming.api.java.*;

public abstract class HistoryObject implements Serializable {

    public JavaPairRDD<String, Map<String, List<Double>>> pairDData;
    public int windowSize; //seconds

    public HistoryObject(JavaStreamingContext jssc) {
        List<Tuple2<String, Map<String, List<Double>>>> tmpDataList = new ArrayList<>();
        //// for test
        //Map<String, List<Double>> testMap = new HashMap<>();
        //List<Double> testList = new ArrayList<Double>();
        //testList.add(7000.0);
        //testList.add(200.0);
        //testMap.put("decision1", testList);
        //tmpDataList.add(new Tuple2("group1", testMap));
        JavaRDD<Tuple2<String, Map<String, List<Double>>>> dData =
                jssc.sparkContext().parallelize(tmpDataList);
        this.pairDData = JavaPairRDD.fromJavaRDD(dData);
    }

    public void updateData(JavaPairRDD<String, Map<String, List<Double>>> newPairDData) {
        this.pairDData = newPairDData;
    }

   /*
    * implement this method for combination of old data and new data
    */
    public abstract Tuple2<String, Map<String, List<Double>>> combineCall(Tuple2<String, Tuple2<
            Iterable<Map<String, List<Double>>>, Iterable<Map<String, List<Double>>>
            >> tuple2);

    /*
     * implement this method for decision making
     */
    public abstract String getDecision(Map<String, List<Double>> decisionStatMap);
}
