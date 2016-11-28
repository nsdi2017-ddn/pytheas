package frontend;

import java.util.*;
import scala.Tuple2;
import org.json.JSONObject;
import org.json.JSONArray;
import org.apache.spark.streaming.api.java.*;

public class HistoryData extends HistoryObject {

    // self defined parameters
    public double epsilon = 0.9;
    // end of self defined

    public HistoryData(JavaStreamingContext jssc) {
        super(jssc);
        windowSize = 10000;
    }

   /*
    * implement this method for combination of old data and new data
    */
    public Tuple2<String, Map<String, List<Double>>> combineCall(Tuple2<String, Tuple2<
            Iterable<Map<String, List<Double>>>, Iterable<Map<String, List<Double>>>
            >> tuple2) {
        Map<String, List<Double>> newData=null;
        Iterator<Map<String, List<Double>>> iter;
        iter = tuple2._2()._1().iterator();
        if (iter.hasNext())
            newData = iter.next();
        if (newData != null) {
            // calculate the average for new records
            for (Map.Entry<String, List<Double>> entry : newData.entrySet()) {
                List<Double> scores = entry.getValue();
                double totalscore = 0;
                for (double score : scores)
                    totalscore += score;
                // here becomes 2-elements list: [sum, size]
                List<Double> countedScore = new ArrayList<>();
                countedScore.add(totalscore);
                countedScore.add((double)scores.size());
                entry.setValue(countedScore);
            }
        }
        return new Tuple2(tuple2._1(), newData);
    }

    /*
     * implement this method for decision making
     */
    public String getDecision(Map<String, List<Double>> decisionStatMap) {
        double maxScore = -Double.MAX_VALUE;
        String bestDecision = null;
        JSONArray jArray = new JSONArray();
        for (Map.Entry<String, List<Double>> entry : decisionStatMap.entrySet()) {
            // TODO: what if here is divided by zero?
            if (entry.getValue().get(0) / entry.getValue().get(1) > maxScore) {
                if (bestDecision != null)
                    jArray.put(bestDecision);
                bestDecision = entry.getKey();
                maxScore = entry.getValue().get(0) / entry.getValue().get(1);
            } else {
                jArray.put(entry.getKey());
            }
        }
        JSONObject jObject = new JSONObject();
        jObject.put("random", jArray);
        jObject.put("best", bestDecision);
        jObject.put("epsilon", epsilon);
        return jObject.toString();
    }
}
