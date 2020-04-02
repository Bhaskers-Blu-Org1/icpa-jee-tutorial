package dev.appsody.jpa.dao;

import java.util.List;

import javax.enterprise.context.Dependent;
import javax.persistence.EntityManager;
import javax.persistence.PersistenceContext;

@Dependent
public class GenericDao<T> {

    @PersistenceContext(name = "jee-sample")
    private EntityManager em;

    public void create(T resource) {
        em.persist(resource);
    }

    public T find(Class<T> clazz, String resourceId) {
        return em.find(clazz, resourceId);
    }

    public void updateDepartment(T resource) {
        em.merge(resource);
    }

    public void deleteDepartment(T resource) {
        em.remove(resource);
    }

    /**
     *
     * Assumes all JPA entities in this application have a
     * "findAll" named query.
     */
    public List<T> readAll(Class<T> clazz) {
        return em.createNamedQuery(clazz.getSimpleName() + ".findAll", clazz).getResultList();
    }
}
